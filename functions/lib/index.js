import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { DateTime } from "luxon";
initializeApp();
const db = getFirestore();
const devicesCollection = "notificationDevices";
const functionsRegion = "europe-west1";
const priceTimeZone = "Europe/Tallinn";
const regions = ["EE", "LV", "LT", "FI"];
const chartResolutions = ["15min", "1h"];
const regionKeys = {
    EE: "ee",
    LV: "lv",
    LT: "lt",
    FI: "fi",
};
const taxRates = {
    EE: 1.24,
    LV: 1.21,
    LT: 1.21,
    FI: 1.255,
};
const locales = {
    et: "et-EE",
    en: "en-US",
    fi: "fi-FI",
    ru: "ru-RU",
};
const titles = {
    max: {
        et: "Kõrge elektrihind",
        en: "High electricity price",
        fi: "Korkea sähkön hinta",
        ru: "Высокая цена на электроэнергию",
    },
    min: {
        et: "Madal elektrihind",
        en: "Low electricity price",
        fi: "Matala sähkön hinta",
        ru: "Низкая цена на электроэнергию",
    },
};
class BadRequest extends Error {
}
export const syncNotificationDevice = onCall({ region: functionsRegion }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const registration = parseDeviceRegistration(request.data);
    await db.collection(devicesCollection).doc(request.auth.uid).set(removeUndefined({
        ...registration,
        uid: request.auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
    }), { merge: true });
    return { ok: true };
});
export const sendTestNotification = onCall({ region: functionsRegion }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const snapshot = await db.collection(devicesCollection).doc(request.auth.uid).get();
    if (!snapshot.exists) {
        throw new HttpsError("failed-precondition", "Notification device is not registered.");
    }
    const device = snapshot.data();
    if (!device.fcmToken) {
        throw new HttpsError("failed-precondition", "Notification device has no FCM token.");
    }
    await getMessaging().send({
        token: device.fcmToken,
        notification: {
            title: "NordPrice test notification",
            body: "Firebase Cloud Messaging is configured.",
        },
        data: {
            type: "test_push",
        },
        apns: {
            headers: {
                "apns-push-type": "alert",
                "apns-priority": "10",
            },
            payload: {
                aps: {
                    sound: "default",
                },
            },
        },
    });
    return { ok: true };
});
export const checkTomorrowPrices = onSchedule({
    region: functionsRegion,
    schedule: "15,45 14-16 * * *",
    timeZone: priceTimeZone,
    timeoutSeconds: 540,
    memory: "256MiB",
}, async () => {
    const summary = await runPriceCheck();
    logger.info("Tomorrow price check completed", summary);
});
async function runPriceCheck() {
    const window = tomorrowWindow();
    const prices = await fetchTomorrowPrices(window);
    const incomplete = regions.filter((region) => prices[region].length !== window.expectedIntervalCount);
    if (incomplete.length > 0) {
        logger.info("Tomorrow prices are not complete yet", {
            date: window.date,
            expectedIntervalCount: window.expectedIntervalCount,
            counts: Object.fromEntries(regions.map((region) => [region, prices[region].length])),
        });
        return {
            date: window.date,
            dataReady: false,
            checkedDevices: 0,
            sent: 0,
            failed: 0,
            skippedAlreadySent: 0,
        };
    }
    let checkedDevices = 0;
    let sent = 0;
    let failed = 0;
    let skippedAlreadySent = 0;
    for (const region of regions) {
        const pointsByResolution = {
            "15min": prices[region],
            "1h": aggregateToHourly(prices[region]),
        };
        const devices = await activeDevices(region);
        for (const device of devices) {
            checkedDevices += 1;
            const points = pointsByResolution[chartResolution(device)];
            const highest = maxPrice(points);
            const lowest = minPrice(points);
            if (device.notifyMaxEnabled && highest.price >= device.notifyMaxRawMWh) {
                if (device.lastMaxNotifiedDate === window.date) {
                    skippedAlreadySent += 1;
                }
                else {
                    const ok = await sendPriceNotification({
                        device,
                        direction: "max",
                        date: window.date,
                        point: highest,
                        thresholdRawMWh: device.notifyMaxRawMWh,
                    });
                    ok ? (sent += 1) : (failed += 1);
                }
            }
            if (device.notifyMinEnabled && lowest.price <= device.notifyMinRawMWh) {
                if (device.lastMinNotifiedDate === window.date) {
                    skippedAlreadySent += 1;
                }
                else {
                    const ok = await sendPriceNotification({
                        device,
                        direction: "min",
                        date: window.date,
                        point: lowest,
                        thresholdRawMWh: device.notifyMinRawMWh,
                    });
                    ok ? (sent += 1) : (failed += 1);
                }
            }
        }
    }
    return {
        date: window.date,
        dataReady: true,
        checkedDevices,
        sent,
        failed,
        skippedAlreadySent,
    };
}
function tomorrowWindow(now = DateTime.now()) {
    const start = now.setZone(priceTimeZone).plus({ days: 1 }).startOf("day");
    const endExclusive = start.plus({ days: 1 });
    const endInclusive = endExclusive.minus({ millisecond: 1 });
    const expectedIntervalCount = endExclusive.diff(start, "minutes").minutes / 15;
    return {
        date: start.toISODate(),
        expectedIntervalCount,
        startUtc: start.toUTC().toISO({ suppressMilliseconds: false }),
        endUtc: endInclusive.toUTC().toISO({ suppressMilliseconds: false }),
    };
}
async function fetchTomorrowPrices(window) {
    const params = new URLSearchParams({
        start: window.startUtc,
        end: window.endUtc,
    });
    const url = `https://dashboard.elering.ee/api/nps/price?${params.toString()}`;
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Elering request failed with ${response.status}`);
    }
    const payload = (await response.json());
    return {
        EE: payload.data[regionKeys.EE] ?? [],
        LV: payload.data[regionKeys.LV] ?? [],
        LT: payload.data[regionKeys.LT] ?? [],
        FI: payload.data[regionKeys.FI] ?? [],
    };
}
async function activeDevices(region) {
    const snapshot = await db
        .collection(devicesCollection)
        .where("enabled", "==", true)
        .where("region", "==", region)
        .get();
    return snapshot.docs
        .map((doc) => ({ id: doc.id, ref: doc.ref, ...doc.data() }))
        .filter((device) => Boolean(device.fcmToken));
}
function maxPrice(points) {
    return points.reduce((best, point) => (point.price > best.price ? point : best), points[0]);
}
function minPrice(points) {
    return points.reduce((best, point) => (point.price < best.price ? point : best), points[0]);
}
function aggregateToHourly(points) {
    const buckets = new Map();
    for (const point of points) {
        const hourStart = Math.floor(DateTime.fromSeconds(point.timestamp, { zone: "utc" })
            .setZone(priceTimeZone)
            .startOf("hour")
            .toMillis() / 1000);
        const bucket = buckets.get(hourStart) ?? { sum: 0, count: 0 };
        bucket.sum += point.price;
        bucket.count += 1;
        buckets.set(hourStart, bucket);
    }
    return Array.from(buckets.entries())
        .sort(([left], [right]) => left - right)
        .map(([timestamp, bucket]) => ({
        timestamp,
        price: bucket.sum / bucket.count,
    }));
}
function chartResolution(device) {
    return device.chartResolution === "15min" ? "15min" : "1h";
}
async function sendPriceNotification(args) {
    const price = formatPrice(args.point.price, args.device);
    const threshold = formatPrice(args.thresholdRawMWh, args.device);
    const time = formatHour(args.point.timestamp, args.device.region);
    const title = notificationTitle(args.direction, args.device.language);
    const body = notificationBody({
        direction: args.direction,
        language: args.device.language,
        price,
        threshold,
        unit: args.device.unit,
        time,
    });
    const message = {
        token: args.device.fcmToken,
        notification: {
            title,
            body,
        },
        data: {
            type: `price_threshold_${args.direction}`,
            direction: args.direction,
            region: args.device.region,
            date: args.date,
        },
        apns: {
            headers: {
                "apns-push-type": "alert",
                "apns-priority": "10",
            },
            payload: {
                aps: {
                    sound: "default",
                },
            },
        },
    };
    try {
        await getMessaging().send(message);
        await args.device.ref.set({
            [args.direction === "max" ? "lastMaxNotifiedDate" : "lastMinNotifiedDate"]: args.date,
            updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
    }
    catch (error) {
        if (isInvalidToken(error)) {
            await args.device.ref.set({
                enabled: false,
                invalidTokenAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        logger.warn("FCM push failed", {
            deviceId: args.device.id,
            error,
        });
        return false;
    }
}
function isInvalidToken(error) {
    const code = error.code;
    return (code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered");
}
function displayPrice(rawMWh, device) {
    const taxRate = device.includeTax ? taxRates[device.region] : 1;
    return (rawMWh * taxRate) / divider(device.unit);
}
function formatPrice(rawMWh, device) {
    const language = languageKey(device.language);
    const value = displayPrice(rawMWh, device);
    const digits = minimumFractionDigits(device.unit);
    return new Intl.NumberFormat(locales[language], {
        minimumFractionDigits: digits,
        maximumFractionDigits: Math.max(digits, 4),
    }).format(value);
}
function notificationTitle(direction, language) {
    const key = languageKey(language);
    return titles[direction][key] ?? titles[direction].en;
}
function notificationBody(args) {
    const key = languageKey(args.language);
    const price = `${args.price} ${args.unit}`;
    const threshold = `${args.threshold} ${args.unit}`;
    if (args.direction === "max") {
        switch (key) {
            case "et":
                return `Homne kõrgeim hind ${price} kell ${args.time} ületab sinu seatud piiri (${threshold}).`;
            case "fi":
                return `Huomisen korkein hinta ${price} klo ${args.time} ylittää asettamasi rajan (${threshold}).`;
            case "ru":
                return `Завтрашний пик ${price} в ${args.time} превышает заданный лимит (${threshold}).`;
            default:
                return `Tomorrow's peak ${price} at ${args.time} exceeds your set limit (${threshold}).`;
        }
    }
    switch (key) {
        case "et":
            return `Homne madalaim hind ${price} kell ${args.time} on alla sinu seatud piiri (${threshold}).`;
        case "fi":
            return `Huomisen alin hinta ${price} klo ${args.time} alittaa asettamasi rajan (${threshold}).`;
        case "ru":
            return `Завтрашний минимум ${price} в ${args.time} ниже заданного лимита (${threshold}).`;
        default:
            return `Tomorrow's low ${price} at ${args.time} is below your set limit (${threshold}).`;
    }
}
function formatHour(timestampSeconds, region) {
    const timeZone = region === "FI" ? "Europe/Helsinki" : "Europe/Tallinn";
    return new Intl.DateTimeFormat("et-EE", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone,
    }).format(new Date(timestampSeconds * 1000));
}
function divider(unit) {
    if (unit === "€/MWh")
        return 1;
    if (unit === "cent/kWh" || unit === "senti/kWh")
        return 10;
    return 1000;
}
function minimumFractionDigits(unit) {
    if (unit === "€/kWh")
        return 4;
    return 1;
}
function languageKey(language) {
    if (language.startsWith("fi"))
        return "fi";
    if (language.startsWith("ru"))
        return "ru";
    if (language.startsWith("en"))
        return "en";
    return "et";
}
function parseDeviceRegistration(data) {
    if (typeof data !== "object" || data == null || Array.isArray(data)) {
        throw new HttpsError("invalid-argument", "Device registration object is required.");
    }
    try {
        const input = data;
        const notifyMaxEnabled = booleanField(input, "notifyMaxEnabled");
        const notifyMinEnabled = booleanField(input, "notifyMinEnabled");
        const enabled = booleanField(input, "enabled");
        if (enabled !== (notifyMaxEnabled || notifyMinEnabled)) {
            throw new BadRequest("enabled does not match notification settings");
        }
        const registration = {
            installationId: stringField(input, "installationId"),
            platform: oneOf(stringField(input, "platform"), ["ios"], "platform"),
            bundleId: stringField(input, "bundleId"),
            fcmToken: stringField(input, "fcmToken"),
            region: oneOf(stringField(input, "region"), regions, "region"),
            language: stringField(input, "language"),
            unit: stringField(input, "unit"),
            includeTax: booleanField(input, "includeTax"),
            chartResolution: oneOf(optionalString(input, "chartResolution") ?? "1h", chartResolutions, "chartResolution"),
            notifyMaxEnabled,
            notifyMaxRawMWh: numberField(input, "notifyMaxRawMWh"),
            notifyMinEnabled,
            notifyMinRawMWh: numberField(input, "notifyMinRawMWh"),
            enabled,
        };
        const appVersion = optionalString(input, "appVersion");
        const buildNumber = optionalString(input, "buildNumber");
        if (appVersion)
            registration.appVersion = appVersion;
        if (buildNumber)
            registration.buildNumber = buildNumber;
        return registration;
    }
    catch (error) {
        if (error instanceof BadRequest) {
            throw new HttpsError("invalid-argument", error.message);
        }
        throw error;
    }
}
function stringField(input, key) {
    const value = input[key];
    if (typeof value !== "string" || value.trim() === "") {
        throw new BadRequest(`${key} is required`);
    }
    return value.trim();
}
function optionalString(input, key) {
    const value = input[key];
    if (value == null || value === "")
        return undefined;
    if (typeof value !== "string")
        throw new BadRequest(`${key} must be a string`);
    return value.trim();
}
function booleanField(input, key) {
    const value = input[key];
    if (typeof value !== "boolean")
        throw new BadRequest(`${key} must be a boolean`);
    return value;
}
function numberField(input, key) {
    const value = input[key];
    if (typeof value !== "number" || !Number.isFinite(value)) {
        throw new BadRequest(`${key} must be a number`);
    }
    return value;
}
function oneOf(value, allowed, fieldName) {
    if (!allowed.includes(value)) {
        throw new BadRequest(`${fieldName} must be one of ${allowed.join(", ")}`);
    }
    return value;
}
function removeUndefined(input) {
    return Object.fromEntries(Object.entries(input).filter(([, value]) => value !== undefined));
}
//# sourceMappingURL=index.js.map
import { pool } from "./db.js";
import {
  formatHour,
  formatPrice,
  notificationBody,
  notificationTitle,
} from "./format.js";
import { fetchTomorrowPrices, tomorrowWindow } from "./priceClient.js";
import { sendAlertPush } from "./apns.js";
import type { DeviceRow, NotificationDirection, PricePoint, Region } from "./types.js";
import { regions } from "./types.js";

export interface PriceCheckSummary {
  date: string;
  dataReady: boolean;
  checkedDevices: number;
  sent: number;
  failed: number;
  skippedAlreadySent: number;
}

function rawNumber(value: string | number): number {
  return typeof value === "number" ? value : Number(value);
}

function dateString(value: string | Date | null): string | null {
  if (value == null) return null;
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return value.slice(0, 10);
}

async function activeDevices(region: Region): Promise<DeviceRow[]> {
  const result = await pool.query<DeviceRow>(
    `
      SELECT *
      FROM device_settings
      WHERE disabled_at IS NULL
        AND region = $1
        AND (notify_max_enabled = true OR notify_min_enabled = true)
    `,
    [region],
  );
  return result.rows;
}

function maxPrice(points: PricePoint[]): PricePoint {
  return points.reduce((best, point) => (point.price > best.price ? point : best), points[0]);
}

function minPrice(points: PricePoint[]): PricePoint {
  return points.reduce((best, point) => (point.price < best.price ? point : best), points[0]);
}

function hasAlreadySent(device: DeviceRow, direction: NotificationDirection, date: string): boolean {
  const stored =
    direction === "max"
      ? dateString(device.last_max_notified_date)
      : dateString(device.last_min_notified_date);
  return stored === date;
}

async function markSent(
  installationId: string,
  direction: NotificationDirection,
  date: string,
): Promise<void> {
  const column = direction === "max" ? "last_max_notified_date" : "last_min_notified_date";
  await pool.query(
    `
      UPDATE device_settings
      SET ${column} = $2::date, updated_at = now()
      WHERE installation_id = $1
    `,
    [installationId, date],
  );
}

async function disableInvalidDevice(installationId: string): Promise<void> {
  await pool.query(
    `
      UPDATE device_settings
      SET disabled_at = now(), updated_at = now()
      WHERE installation_id = $1
    `,
    [installationId],
  );
}

function isInvalidToken(reason?: string, status?: number): boolean {
  return (
    status === 410 ||
    reason === "BadDeviceToken" ||
    reason === "Unregistered" ||
    reason === "DeviceTokenNotForTopic"
  );
}

async function sendPriceNotification(args: {
  device: DeviceRow;
  direction: NotificationDirection;
  date: string;
  point: PricePoint;
  thresholdRawMWh: number;
}): Promise<boolean> {
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

  const result = await sendAlertPush(
    args.device,
    { title, body },
    {
      type: `price_threshold_${args.direction}`,
      region: args.device.region,
      date: args.date,
    },
  );

  if (result.ok) {
    await markSent(args.device.installation_id, args.direction, args.date);
    return true;
  }

  if (isInvalidToken(result.reason, result.status)) {
    await disableInvalidDevice(args.device.installation_id);
  }

  console.warn("APNs push failed", {
    installationId: args.device.installation_id,
    status: result.status,
    reason: result.reason,
  });
  return false;
}

export async function runPriceCheck(): Promise<PriceCheckSummary> {
  const window = tomorrowWindow();
  const prices = await fetchTomorrowPrices();
  const incomplete = regions.filter(
    (region) => prices[region].length !== window.expectedHourCount,
  );

  if (incomplete.length > 0) {
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
    const points = prices[region];
    const highest = maxPrice(points);
    const lowest = minPrice(points);
    const devices = await activeDevices(region);

    for (const device of devices) {
      checkedDevices += 1;

      if (
        device.notify_max_enabled &&
        highest.price >= rawNumber(device.notify_max_raw_mwh)
      ) {
        if (hasAlreadySent(device, "max", window.date)) {
          skippedAlreadySent += 1;
        } else {
          const ok = await sendPriceNotification({
            device,
            direction: "max",
            date: window.date,
            point: highest,
            thresholdRawMWh: rawNumber(device.notify_max_raw_mwh),
          });
          ok ? (sent += 1) : (failed += 1);
        }
      }

      if (
        device.notify_min_enabled &&
        lowest.price <= rawNumber(device.notify_min_raw_mwh)
      ) {
        if (hasAlreadySent(device, "min", window.date)) {
          skippedAlreadySent += 1;
        } else {
          const ok = await sendPriceNotification({
            device,
            direction: "min",
            date: window.date,
            point: lowest,
            thresholdRawMWh: rawNumber(device.notify_min_raw_mwh),
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

export async function sendTestNotification(device: DeviceRow): Promise<boolean> {
  const result = await sendAlertPush(
    device,
    {
      title: "Elektrihind test notification",
      body: "Server-side push notifications are configured.",
    },
    { type: "test_push" },
  );

  if (!result.ok) {
    console.warn("APNs test push failed", {
      installationId: device.installation_id,
      status: result.status,
      reason: result.reason,
    });
  }

  return result.ok;
}

import type { DeviceRow, NotificationDirection, Region } from "./types.js";

const taxRates: Record<Region, number> = {
  EE: 1.24,
  LV: 1.21,
  LT: 1.21,
  FI: 1.255,
};

const locales: Record<string, string> = {
  et: "et-EE",
  en: "en-US",
  fi: "fi-FI",
  ru: "ru-RU",
};

const titles: Record<NotificationDirection, Record<string, string>> = {
  max: {
    et: "Kõrge elektrihind homme",
    en: "High electricity price tomorrow",
    fi: "Korkea sähkön hinta huomenna",
    ru: "Высокая цена на электроэнергию завтра",
  },
  min: {
    et: "Madal elektrihind homme",
    en: "Low electricity price tomorrow",
    fi: "Matala sähkön hinta huomenna",
    ru: "Низкая цена на электроэнергию завтра",
  },
};

function divider(unit: string): number {
  if (unit === "€/MWh") return 1;
  if (unit === "cent/kWh" || unit === "senti/kWh") return 10;
  return 1000;
}

function minimumFractionDigits(unit: string): number {
  if (unit === "€/kWh") return 4;
  return 1;
}

function languageKey(language: string): string {
  if (language.startsWith("fi")) return "fi";
  if (language.startsWith("ru")) return "ru";
  if (language.startsWith("en")) return "en";
  return "et";
}

export function displayPrice(rawMWh: number, device: DeviceRow): number {
  const taxRate = device.include_tax ? taxRates[device.region] : 1;
  return (rawMWh * taxRate) / divider(device.unit);
}

export function formatPrice(rawMWh: number, device: DeviceRow): string {
  const language = languageKey(device.language);
  const value = displayPrice(rawMWh, device);
  const digits = minimumFractionDigits(device.unit);
  return new Intl.NumberFormat(locales[language], {
    minimumFractionDigits: digits,
    maximumFractionDigits: Math.max(digits, 4),
  }).format(value);
}

export function notificationTitle(
  direction: NotificationDirection,
  language: string,
): string {
  const key = languageKey(language);
  return titles[direction][key] ?? titles[direction].en;
}

export function notificationBody(args: {
  direction: NotificationDirection;
  language: string;
  price: string;
  threshold: string;
  unit: string;
  time: string;
}): string {
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

export function formatHour(timestampSeconds: number, region: Region): string {
  const timeZone = region === "FI" ? "Europe/Helsinki" : "Europe/Tallinn";
  return new Intl.DateTimeFormat("et-EE", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone,
  }).format(new Date(timestampSeconds * 1000));
}

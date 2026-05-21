import { DateTime } from "luxon";
import { config } from "./config.js";
import type { PricePoint, Region } from "./types.js";

type EleringRegionKey = "ee" | "lv" | "lt" | "fi";

interface EleringResponse {
  data: Record<EleringRegionKey, PricePoint[]>;
}

const regionKeys: Record<Region, EleringRegionKey> = {
  EE: "ee",
  LV: "lv",
  LT: "lt",
  FI: "fi",
};

export function tomorrowWindow(now = DateTime.now()) {
  const start = now.setZone(config.timeZone).plus({ days: 1 }).startOf("day");
  const endExclusive = start.plus({ days: 1 });
  const endInclusive = endExclusive.minus({ millisecond: 1 });

  return {
    date: start.toISODate()!,
    expectedHourCount: endExclusive.diff(start, "hours").hours,
    startUtc: start.toUTC().toISO({ suppressMilliseconds: false })!,
    endUtc: endInclusive.toUTC().toISO({ suppressMilliseconds: false })!,
  };
}

export async function fetchTomorrowPrices(): Promise<Record<Region, PricePoint[]>> {
  const window = tomorrowWindow();
  const params = new URLSearchParams({
    start: window.startUtc,
    end: window.endUtc,
  });
  const url = `https://dashboard.elering.ee/api/nps/price?${params.toString()}`;

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Elering request failed with ${response.status}`);
  }

  const payload = (await response.json()) as EleringResponse;
  return {
    EE: payload.data[regionKeys.EE] ?? [],
    LV: payload.data[regionKeys.LV] ?? [],
    LT: payload.data[regionKeys.LT] ?? [],
    FI: payload.data[regionKeys.FI] ?? [],
  };
}

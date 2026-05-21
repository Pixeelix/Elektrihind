export const regions = ["EE", "LV", "LT", "FI"] as const;
export type Region = (typeof regions)[number];

export const apnsEnvironments = ["sandbox", "production"] as const;
export type ApnsEnvironment = (typeof apnsEnvironments)[number];

export interface PricePoint {
  timestamp: number;
  price: number;
}

export interface DeviceRegistration {
  installationId: string;
  platform: "ios";
  bundleId: string;
  apnsToken: string;
  apnsEnvironment: ApnsEnvironment;
  region: Region;
  language: string;
  unit: string;
  includeTax: boolean;
  notifyMaxEnabled: boolean;
  notifyMaxRawMWh: number;
  notifyMinEnabled: boolean;
  notifyMinRawMWh: number;
  appVersion?: string | null;
  buildNumber?: string | null;
}

export interface DeviceRow {
  installation_id: string;
  platform: "ios";
  bundle_id: string;
  apns_token: string;
  apns_environment: ApnsEnvironment;
  region: Region;
  language: string;
  unit: string;
  include_tax: boolean;
  notify_max_enabled: boolean;
  notify_max_raw_mwh: string | number;
  notify_min_enabled: boolean;
  notify_min_raw_mwh: string | number;
  last_max_notified_date: string | Date | null;
  last_min_notified_date: string | Date | null;
}

export type NotificationDirection = "max" | "min";

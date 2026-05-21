import {
  apnsEnvironments,
  type ApnsEnvironment,
  type DeviceRegistration,
  type Region,
  regions,
} from "./types.js";

export class BadRequest extends Error {
  status = 400;
}

function stringField(input: Record<string, unknown>, key: string): string {
  const value = input[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw new BadRequest(`${key} is required`);
  }
  return value.trim();
}

function optionalString(input: Record<string, unknown>, key: string): string | null {
  const value = input[key];
  if (value == null || value === "") return null;
  if (typeof value !== "string") throw new BadRequest(`${key} must be a string`);
  return value.trim();
}

function booleanField(input: Record<string, unknown>, key: string): boolean {
  const value = input[key];
  if (typeof value !== "boolean") throw new BadRequest(`${key} must be a boolean`);
  return value;
}

function numberField(input: Record<string, unknown>, key: string): number {
  const value = input[key];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new BadRequest(`${key} must be a number`);
  }
  return value;
}

function oneOf<T extends readonly string[]>(
  value: string,
  allowed: T,
  fieldName: string,
): T[number] {
  if (!allowed.includes(value)) {
    throw new BadRequest(`${fieldName} must be one of ${allowed.join(", ")}`);
  }
  return value as T[number];
}

export function parseDeviceRegistration(body: unknown): DeviceRegistration {
  if (typeof body !== "object" || body == null || Array.isArray(body)) {
    throw new BadRequest("JSON object body is required");
  }

  const input = body as Record<string, unknown>;
  const region = oneOf(stringField(input, "region"), regions, "region") as Region;
  const apnsEnvironment = oneOf(
    stringField(input, "apnsEnvironment"),
    apnsEnvironments,
    "apnsEnvironment",
  ) as ApnsEnvironment;

  return {
    installationId: stringField(input, "installationId"),
    platform: "ios",
    bundleId: stringField(input, "bundleId"),
    apnsToken: stringField(input, "apnsToken"),
    apnsEnvironment,
    region,
    language: stringField(input, "language"),
    unit: stringField(input, "unit"),
    includeTax: booleanField(input, "includeTax"),
    notifyMaxEnabled: booleanField(input, "notifyMaxEnabled"),
    notifyMaxRawMWh: numberField(input, "notifyMaxRawMWh"),
    notifyMinEnabled: booleanField(input, "notifyMinEnabled"),
    notifyMinRawMWh: numberField(input, "notifyMinRawMWh"),
    appVersion: optionalString(input, "appVersion"),
    buildNumber: optionalString(input, "buildNumber"),
  };
}

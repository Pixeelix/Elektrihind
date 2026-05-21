import dotenv from "dotenv";

dotenv.config();

function bool(name: string, fallback = false): boolean {
  const value = process.env[name];
  if (value == null || value === "") return fallback;
  return ["1", "true", "yes", "on"].includes(value.toLowerCase());
}

function number(name: string, fallback: number): number {
  const value = process.env[name];
  if (value == null || value === "") return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`${name} must be a number`);
  }
  return parsed;
}

function optionalPrivateKey(): string | undefined {
  const base64 = process.env.APNS_PRIVATE_KEY_BASE64?.trim();
  if (base64) {
    return Buffer.from(base64, "base64").toString("utf8");
  }

  const raw = process.env.APNS_PRIVATE_KEY?.trim();
  if (!raw) return undefined;
  return raw.replace(/\\n/g, "\n");
}

export const config = {
  port: number("PORT", 8080),
  databaseUrl: process.env.DATABASE_URL ?? "",
  databaseSsl: bool("DATABASE_SSL"),
  adminApiKey: process.env.ADMIN_API_KEY ?? "",
  timeZone: "Europe/Tallinn",
  apns: {
    teamId: process.env.APNS_TEAM_ID ?? "",
    keyId: process.env.APNS_KEY_ID ?? "",
    bundleId: process.env.APNS_BUNDLE_ID ?? "koodipardik.Elektrihind",
    privateKey: optionalPrivateKey(),
  },
};

export function requireDatabaseUrl(): string {
  if (!config.databaseUrl) {
    throw new Error("DATABASE_URL is required");
  }
  return config.databaseUrl;
}

export function requireAdminApiKey(): string {
  if (!config.adminApiKey) {
    throw new Error("ADMIN_API_KEY is required");
  }
  return config.adminApiKey;
}

export function requireApnsConfig() {
  const missing = [
    ["APNS_TEAM_ID", config.apns.teamId],
    ["APNS_KEY_ID", config.apns.keyId],
    ["APNS_PRIVATE_KEY or APNS_PRIVATE_KEY_BASE64", config.apns.privateKey],
  ].filter(([, value]) => !value);

  if (missing.length > 0) {
    throw new Error(`Missing APNs config: ${missing.map(([name]) => name).join(", ")}`);
  }

  return {
    teamId: config.apns.teamId,
    keyId: config.apns.keyId,
    bundleId: config.apns.bundleId,
    privateKey: config.apns.privateKey!,
  };
}

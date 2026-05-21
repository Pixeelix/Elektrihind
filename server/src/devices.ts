import { pool } from "./db.js";
import type { DeviceRegistration, DeviceRow } from "./types.js";

export async function upsertDevice(registration: DeviceRegistration): Promise<void> {
  const disabledAt =
    registration.notifyMaxEnabled || registration.notifyMinEnabled ? null : new Date();

  await pool.query(
    `
      INSERT INTO device_settings (
        installation_id,
        platform,
        bundle_id,
        apns_token,
        apns_environment,
        region,
        language,
        unit,
        include_tax,
        notify_max_enabled,
        notify_max_raw_mwh,
        notify_min_enabled,
        notify_min_raw_mwh,
        app_version,
        build_number,
        disabled_at
      )
      VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8,
        $9, $10, $11, $12, $13, $14, $15, $16
      )
      ON CONFLICT (installation_id) DO UPDATE SET
        platform = excluded.platform,
        bundle_id = excluded.bundle_id,
        apns_token = excluded.apns_token,
        apns_environment = excluded.apns_environment,
        region = excluded.region,
        language = excluded.language,
        unit = excluded.unit,
        include_tax = excluded.include_tax,
        notify_max_enabled = excluded.notify_max_enabled,
        notify_max_raw_mwh = excluded.notify_max_raw_mwh,
        notify_min_enabled = excluded.notify_min_enabled,
        notify_min_raw_mwh = excluded.notify_min_raw_mwh,
        app_version = excluded.app_version,
        build_number = excluded.build_number,
        disabled_at = excluded.disabled_at,
        updated_at = now()
    `,
    [
      registration.installationId,
      registration.platform,
      registration.bundleId,
      registration.apnsToken,
      registration.apnsEnvironment,
      registration.region,
      registration.language,
      registration.unit,
      registration.includeTax,
      registration.notifyMaxEnabled,
      registration.notifyMaxRawMWh,
      registration.notifyMinEnabled,
      registration.notifyMinRawMWh,
      registration.appVersion,
      registration.buildNumber,
      disabledAt,
    ],
  );
}

export async function disableDevice(installationId: string): Promise<void> {
  await pool.query(
    `
      UPDATE device_settings
      SET disabled_at = now(), updated_at = now()
      WHERE installation_id = $1
    `,
    [installationId],
  );
}

export async function getDevice(installationId: string): Promise<DeviceRow | null> {
  const result = await pool.query<DeviceRow>(
    `
      SELECT *
      FROM device_settings
      WHERE installation_id = $1
    `,
    [installationId],
  );
  return result.rows[0] ?? null;
}

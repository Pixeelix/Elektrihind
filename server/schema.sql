CREATE TABLE IF NOT EXISTS device_settings (
  installation_id text PRIMARY KEY,
  platform text NOT NULL DEFAULT 'ios',
  bundle_id text NOT NULL,
  apns_token text NOT NULL,
  apns_environment text NOT NULL CHECK (apns_environment IN ('sandbox', 'production')),
  region text NOT NULL CHECK (region IN ('EE', 'LV', 'LT', 'FI')),
  language text NOT NULL DEFAULT 'et',
  unit text NOT NULL DEFAULT '€/kWh',
  include_tax boolean NOT NULL DEFAULT false,
  notify_max_enabled boolean NOT NULL DEFAULT false,
  notify_max_raw_mwh numeric NOT NULL DEFAULT 200,
  notify_min_enabled boolean NOT NULL DEFAULT false,
  notify_min_raw_mwh numeric NOT NULL DEFAULT 0,
  app_version text,
  build_number text,
  last_max_notified_date date,
  last_min_notified_date date,
  disabled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS device_settings_region_active_idx
  ON device_settings(region)
  WHERE disabled_at IS NULL;

CREATE INDEX IF NOT EXISTS device_settings_apns_token_idx
  ON device_settings(apns_token);

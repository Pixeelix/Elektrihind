import http2 from "node:http2";
import { importPKCS8, SignJWT } from "jose";
import { config, requireApnsConfig } from "./config.js";
import type { DeviceRow } from "./types.js";

interface AlertContent {
  title: string;
  body: string;
}

export interface ApnsResult {
  ok: boolean;
  status: number;
  reason?: string;
}

let cachedJwt: { value: string; createdAtMs: number } | null = null;
let cachedSigningKey: Awaited<ReturnType<typeof importPKCS8>> | null = null;

async function providerToken(): Promise<string> {
  const now = Date.now();
  if (cachedJwt && now - cachedJwt.createdAtMs < 45 * 60 * 1000) {
    return cachedJwt.value;
  }

  const apns = requireApnsConfig();
  cachedSigningKey ??= await importPKCS8(apns.privateKey, "ES256");

  const value = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: apns.keyId })
    .setIssuer(apns.teamId)
    .setIssuedAt(Math.floor(now / 1000))
    .sign(cachedSigningKey);

  cachedJwt = { value, createdAtMs: now };
  return value;
}

function hostFor(device: DeviceRow): string {
  return device.apns_environment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
}

export async function sendAlertPush(
  device: DeviceRow,
  alert: AlertContent,
  data: Record<string, string>,
): Promise<ApnsResult> {
  const jwt = await providerToken();
  const payload = JSON.stringify({
    aps: {
      alert,
      sound: "default",
    },
    ...data,
  });

  return new Promise((resolve, reject) => {
    const client = http2.connect(hostFor(device));
    const chunks: string[] = [];

    client.on("error", reject);

    const request = client.request({
      ":method": "POST",
      ":path": `/3/device/${device.apns_token}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": device.bundle_id || config.apns.bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
    });

    request.setEncoding("utf8");
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("error", (error) => {
      client.close();
      reject(error);
    });
    request.on("response", (headers) => {
      const status = Number(headers[":status"] ?? 0);
      request.on("end", () => {
        client.close();
        let reason: string | undefined;
        const body = chunks.join("");
        if (body) {
          try {
            reason = JSON.parse(body).reason;
          } catch {
            reason = body;
          }
        }
        resolve({ ok: status >= 200 && status < 300, status, reason });
      });
    });

    request.end(payload);
  });
}

import express, { type NextFunction, type Request, type Response } from "express";
import { config, requireAdminApiKey } from "./config.js";
import { disableDevice, getDevice, upsertDevice } from "./devices.js";
import { closePool, pool } from "./db.js";
import { runPriceCheck, sendTestNotification } from "./notifications.js";
import { BadRequest, parseDeviceRegistration } from "./validation.js";

function requireAdmin(req: Request, res: Response, next: NextFunction): void {
  const expected = requireAdminApiKey();
  const bearer = req.header("authorization")?.replace(/^Bearer\s+/i, "");
  const header = req.header("x-admin-key");

  if (bearer !== expected && header !== expected) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }

  next();
}

export function createApp() {
  const app = express();
  app.use(express.json({ limit: "64kb" }));

  app.get("/health", async (_req, res, next) => {
    try {
      await pool.query("SELECT 1");
      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/devices", async (req, res, next) => {
    try {
      const registration = parseDeviceRegistration(req.body);
      await upsertDevice(registration);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  app.delete("/v1/devices/:installationId", async (req, res, next) => {
    try {
      await disableDevice(req.params.installationId);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  app.post("/admin/check-prices", requireAdmin, async (_req, res, next) => {
    try {
      const summary = await runPriceCheck();
      res.json(summary);
    } catch (error) {
      next(error);
    }
  });

  app.post("/admin/test-push/:installationId", requireAdmin, async (req, res, next) => {
    try {
      const device = await getDevice(req.params.installationId);
      if (!device) {
        res.status(404).json({ error: "device not found" });
        return;
      }

      const ok = await sendTestNotification(device);
      res.status(ok ? 200 : 502).json({ ok });
    } catch (error) {
      next(error);
    }
  });

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    console.error(error);
    if (error instanceof BadRequest) {
      res.status(error.status).json({ error: error.message });
      return;
    }
    res.status(500).json({ error: "internal server error" });
  });

  return app;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = createApp().listen(config.port, () => {
    console.log(`Elektrihind push server listening on ${config.port}`);
  });

  const shutdown = async () => {
    server.close();
    await closePool();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

import { Hono } from "hono";
import { cors } from "hono/cors";
import { reports } from "./reports";
import { blocklist } from "./blocklist";

export type Env = {
  Bindings: {
    DB: D1Database;
  };
};

const app = new Hono<Env>();

// CORS — allow all origins for now
app.use("*", cors());

// Health check
app.get("/health", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Mount routes
app.route("/api/reports", reports);
app.route("/api/blocklist", blocklist);

export default app;

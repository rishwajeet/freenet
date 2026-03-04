import { Hono } from "hono";
import { cache } from "hono/cache";
import type { Env } from "./index";

export const blocklist = new Hono<Env>();

type ConfirmedDomain = {
  domain: string;
  classification: string;
  failure_type: string;
  report_count: number;
  countries: string;
  confidence: number;
};

type BlocklistVersion = {
  version: number;
  updated_at: string;
};

// Cache blocklist responses for 1 hour via Cloudflare CDN
blocklist.use(
  "/:country",
  cache({
    cacheName: "freenet-blocklist",
    cacheControl: "public, max-age=3600",
  })
);

blocklist.use(
  "/:country/version",
  cache({
    cacheName: "freenet-blocklist-version",
    cacheControl: "public, max-age=300",
  })
);

// GET /api/blocklist/:country — Full blocklist for a country
blocklist.get("/:country", async (c) => {
  const country = c.req.param("country").toUpperCase();
  const db = c.env.DB;

  if (country.length !== 2) {
    return c.json({ error: "Country must be a 2-letter ISO code" }, 400);
  }

  // Get version info
  const versionRow = await db
    .prepare("SELECT version, updated_at FROM blocklist_versions WHERE country = ?")
    .bind(country)
    .first<BlocklistVersion>();

  // Get confirmed domains that include this country
  const rows = await db
    .prepare(
      `SELECT domain, classification, failure_type, report_count, countries, confidence
       FROM confirmed_domains
       WHERE countries LIKE ?
       ORDER BY confidence DESC, report_count DESC`
    )
    .bind(`%"${country}"%`)
    .all<ConfirmedDomain>();

  const domains = rows.results.map((row) => ({
    domain: row.domain,
    classification: row.classification,
    failureType: row.failure_type,
    reportCount: row.report_count,
    countries: JSON.parse(row.countries) as string[],
    confidence: row.confidence,
  }));

  return c.json({
    version: versionRow?.version ?? 0,
    updatedAt: versionRow?.updated_at ?? null,
    country,
    domains,
  });
});

// GET /api/blocklist/:country/version — Quick version check
blocklist.get("/:country/version", async (c) => {
  const country = c.req.param("country").toUpperCase();
  const db = c.env.DB;

  if (country.length !== 2) {
    return c.json({ error: "Country must be a 2-letter ISO code" }, 400);
  }

  const row = await db
    .prepare("SELECT version, updated_at FROM blocklist_versions WHERE country = ?")
    .bind(country)
    .first<BlocklistVersion>();

  return c.json({
    version: row?.version ?? 0,
    updatedAt: row?.updated_at ?? null,
    country,
  });
});

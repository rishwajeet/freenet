-- Block reports from anonymous users
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  domain TEXT NOT NULL,
  country TEXT NOT NULL,
  failure_type TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  app_version TEXT NOT NULL,
  ip_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_reports_domain ON reports(domain);
CREATE INDEX IF NOT EXISTS idx_reports_country ON reports(country);
CREATE INDEX IF NOT EXISTS idx_reports_domain_country ON reports(domain, country);
CREATE INDEX IF NOT EXISTS idx_reports_ip_hash ON reports(ip_hash, created_at);

-- Confirmed blocked domains (aggregated from reports)
CREATE TABLE IF NOT EXISTS confirmed_domains (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  domain TEXT NOT NULL,
  classification TEXT NOT NULL DEFAULT 'unknown',
  failure_type TEXT NOT NULL,
  report_count INTEGER NOT NULL DEFAULT 0,
  countries TEXT NOT NULL DEFAULT '[]',
  confidence REAL NOT NULL DEFAULT 0.0,
  confirmed_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_confirmed_domain ON confirmed_domains(domain);
CREATE INDEX IF NOT EXISTS idx_confirmed_countries ON confirmed_domains(countries);

-- Blocklist version tracker (one row per country)
CREATE TABLE IF NOT EXISTS blocklist_versions (
  country TEXT PRIMARY KEY,
  version INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Rate limit tracker
CREATE TABLE IF NOT EXISTS rate_limits (
  ip_hash TEXT NOT NULL,
  window_start TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (ip_hash, window_start)
);

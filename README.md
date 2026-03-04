<p align="center">
  <img src="FreeNet/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="FreeNet">
</p>

<h1 align="center">FreeNet</h1>

<p align="center">
  <strong>Intelligent internet freedom for macOS</strong><br>
  No blocks. No ads. No friction.
</p>

<p align="center">
  <a href="https://github.com/rishwajeet/freenet/releases/latest"><img src="https://img.shields.io/github/v/release/rishwajeet/freenet?style=flat-square" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/rishwajeet/freenet?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.10-orange?style=flat-square" alt="Swift 5.10">
</p>

---

FreeNet is a macOS menu bar app that makes the internet work the way it should. It doesn't use static domain lists — it **learns** what's blocked, adapts in real-time, and gets smarter with every user.

## How it works

Every request flows through three intelligent pathways:

| Path | What it does | When it's used |
|------|-------------|----------------|
| **Encrypted** | Encrypted DNS (DoH) + ad/tracker blocking | Default for everything |
| **VPN** | WireGuard tunnel through foreign server | Only when encrypted path hits a geo-block |
| **Raw Direct** | Bypass everything | Only for sites that break under encrypted DNS |

**Encrypted is the baseline.** Every request starts there. VPN and Raw Direct are fallbacks, activated only when the system detects they're needed.

### The learning loop

```
Request comes in
     │
     ├── Known BLOCKED? ──→ VPN (skip encrypted, don't waste time)
     ├── Known DNS-HOSTILE? ──→ Raw Direct
     ├── SAFE? (banking, govt) ──→ Raw Direct (never intercept)
     │
     └── Route through ENCRYPTED (default)
              │
              ├── Works? ──→ Serve content (ads blocked). Done.
              │
              └── Failed?
                   ├── Geo-block? ──→ Retry via VPN ──→ LEARN as blocked
                   └── DNS-hostile? ──→ Retry Raw Direct ──→ LEARN as dns-hostile
```

A brand new install routes everything through encrypted DNS. Within minutes, it learns what's blocked and what's DNS-hostile. With crowd intelligence, new users inherit what thousands already learned.

## Features

- **Intelligent routing** — Learns which sites are blocked, DNS-hostile, or safe. Adapts automatically.
- **System-wide ad blocking** — DNS-level blocking works for all apps, not just browsers.
- **Crowd intelligence** — Anonymous block reports aggregated across users. New installs start smart.
- **WireGuard VPN** — Drop any WireGuard `.conf` file. Works with Proton, Mullvad, or any provider.
- **Privacy-first** — No browsing history, no personal data. Just domain + country + failure type.
- **Menu bar native** — Lives in your menu bar. Glanceable stats. Never needs to be opened to work.
- **Live dashboard** — Real-time traffic view, learned domains, ad block counter.

## Install

### Download

Download the latest `.dmg` from [Releases](https://github.com/rishwajeet/freenet/releases/latest).

### Homebrew

```bash
brew install --cask freenet
```

### Build from source

Requirements: macOS 14+, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/rishwajeet/freenet.git
cd freenet
xcodegen generate
open FreeNet.xcodeproj
# Build and Run (Cmd+R)
```

## Setup

1. Launch FreeNet — it appears in your menu bar
2. Drop your WireGuard `.conf` file (from Proton, Mullvad, etc.)
3. Done. FreeNet handles the rest.

The app learns as you browse. Blocked sites route through VPN automatically. Ads disappear. Banking sites stay untouched.

## Architecture

```
FreeNet/
├── App/              # Entry point, global state
├── Views/            # SwiftUI — menu bar, dashboard, settings, setup wizard
├── Engine/           # Mihomo process management, config generation, traffic monitor
├── Intelligence/     # Learning engine, failure detector, domain store, crowd client
├── Models/           # Domain state, traffic events, block reports
├── Helpers/          # WireGuard parser, DNS config, permissions
└── Resources/        # Mihomo binary, safe domain list, app icon

freenet-api/          # Crowd intelligence API (Cloudflare Workers + D1)
```

### Tech stack

- **Proxy engine**: [Mihomo](https://github.com/MetaCubeX/mihomo) (embedded) — routing, WireGuard, TUN, DNS interception
- **Intelligence**: Custom Swift layer — failure detection, learning engine, SQLite domain store
- **Persistence**: [GRDB.swift](https://github.com/groue/GRDB.swift) (SQLite)
- **Config**: [Yams](https://github.com/jpsim/Yams) (YAML generation for Mihomo)
- **Crowd API**: [Hono](https://hono.dev) on Cloudflare Workers with D1
- **UI**: SwiftUI (native macOS)

### Domain states

| State | Meaning | Routes through |
|-------|---------|---------------|
| **Safe** | Banking, govt, UPI, payments | Raw Direct |
| **Blocked** | Geo-blocked / censored | VPN |
| **DNS-Hostile** | Breaks under encrypted DNS | Raw Direct |
| **Unknown** | Everything else | Encrypted (default) |

### Failure detection

The learning engine detects blocks by analyzing:
- TCP connection resets (RST)
- DNS resolution failures (NXDOMAIN)
- TLS handshake failures / SNI blocking
- HTTP 451 (Unavailable for Legal Reasons)
- Response content containing restriction messages
- Connection timeouts (>5s)

## Crowd intelligence

When FreeNet learns a domain is blocked, it anonymously reports:

```json
{ "domain": "example.com", "country": "IN", "failureType": "geo_block" }
```

The central API aggregates reports. When enough users from the same country report the same domain, it's confirmed as blocked and pushed to all users. No personal data, no browsing history.

Users can opt out in Settings.

## Privacy

- No accounts, no sign-ups
- No browsing history transmitted
- Crowd reports contain only: domain, country code, failure type
- Reports are rate-limited and IP-hashed (hash is not reversible)
- All data stays on-device except anonymous crowd reports
- Fully open source — audit the code yourself

## Contributing

Contributions welcome. Please open an issue first to discuss what you'd like to change.

```bash
# Setup
brew install xcodegen
git clone https://github.com/rishwajeet/freenet.git
cd freenet
xcodegen generate
open FreeNet.xcodeproj
```

## License

[MIT](LICENSE)

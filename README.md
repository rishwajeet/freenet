<p align="center">
  <img src="FreeNet/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="FreeNet">
</p>

<h1 align="center">FreeNet</h1>

<p align="center">
  <strong>Intelligent internet freedom for macOS</strong><br>
  Blocked sites load. Ads vanish. Banking stays untouched.
</p>

<p align="center">
  <a href="https://github.com/rishwajeet/freenet/releases/latest"><img src="https://img.shields.io/github/v/release/rishwajeet/freenet?style=flat-square" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/rishwajeet/freenet?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.10-orange?style=flat-square" alt="Swift 5.10">
</p>

---

## Why FreeNet

VPNs route **everything** through a foreign server. Your banking gets laggy, UPI times out, streaming geo-locks the wrong way, and your entire connection slows down. You're paying a speed tax on 100% of your traffic to unblock the 5% that's actually restricted.

DNS-only solutions like NextDNS and AdGuard are great at killing ads, but they can't unblock anything. Blocked sites stay blocked. You still need a VPN for that, and now you're back to toggling.

FreeNet's insight: **different domains need different routes**, and the system can figure this out automatically. Encrypted DNS handles 95% of traffic (with ad blocking). VPN kicks in only for the domains that are actually blocked. Banking and government sites are never intercepted. No manual switching, no speed penalty on traffic that doesn't need it.

## What it does

- Blocked sites load automatically -- no manual VPN toggle
- System-wide ad blocking across all apps, not just browsers
- Banking, UPI, government sites are never intercepted
- 95% of traffic stays fast (encrypted DNS, no foreign server)
- Learns what's blocked in your country and adapts in real-time
- Crowd intelligence: new installs start smart from day one
- WireGuard VPN: drop any `.conf` file (Proton, Mullvad, any provider)
- Full CLI for terminal control (`freenet status`, `freenet traffic --live`)
- Open source, MIT licensed

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
xcodebuild build -scheme FreeNet       # GUI app
xcodebuild build -scheme freenet-cli   # CLI tool
```

## CLI

The `freenet` CLI gives you full terminal control. It shares the same database and engine as the GUI app.

```bash
# Copy to path after building
sudo cp build/Build/Products/Release/freenet /usr/local/bin/
```

| Command | Description |
|---------|-------------|
| `freenet start` | Start the mihomo engine |
| `freenet stop` | Stop the mihomo engine |
| `freenet status` | Show engine status and domain counts |
| `freenet status --json` | Output status as JSON |
| `freenet toggle` | Toggle the engine on or off |
| `freenet domains list` | List all learned domains |
| `freenet domains list --filter blocked` | Filter by classification (safe, blocked, dns-hostile, unknown) |
| `freenet domains lookup example.com` | Check the route decision for a domain |
| `freenet domains learn example.com blocked` | Manually classify a domain |
| `freenet traffic` | Show recent traffic events |
| `freenet traffic --live` | Stream traffic continuously |
| `freenet sync` | Sync crowd intelligence blocklist |
| `freenet config show` | Print the active mihomo config |
| `freenet config reload` | Regenerate and hot-reload config |
| `freenet vpn load wireguard.conf` | Import a WireGuard config file |
| `freenet vpn show` | Show the current VPN configuration |

## Setup

FreeNet has a 6-step guided onboarding that walks you through everything:

1. **Welcome** -- what FreeNet is
2. **The Problem** -- why VPNs and DNS-only tools aren't enough
3. **How it Works** -- the three intelligent pathways (Encrypted / VPN / Direct)
4. **VPN Config** -- drop your WireGuard `.conf` file (optional but recommended)
5. **Permissions** -- one macOS authorization for the local network tunnel
6. **All Set** -- dynamic status showing what's active

After setup, FreeNet lives in your menu bar. It learns as you browse -- blocked sites route through VPN automatically, ads disappear, banking stays untouched.

### Getting your WireGuard config

FreeNet's setup wizard includes step-by-step tutorials for all major VPN providers. Here's a quick reference:

| Provider | How to get your `.conf` file |
|----------|------------------------------|
| **Proton VPN** | Account dashboard → Downloads → WireGuard configuration → Select server → Create → Download |
| **Mullvad** | Account page → WireGuard configuration → Generate key → Select server → Download file |
| **Surfshark** | My account → VPN → Manual setup → Router/Other → WireGuard → Get Credentials → Download |
| **NordVPN** | Get access token from nordvpn.com/servers/tools → Use NordVPN Linux CLI → `nordvpn export-wireguard` |
| **Windscribe** | Account → WireGuard Config Generator → Pick server → Get Config → Download |
| **IVPN** | Account → WireGuard → Configuration → Generate key → Select server → Download |

Don't have a VPN yet? [Mullvad](https://mullvad.net) and [Proton VPN](https://protonvpn.com) both have free or easy WireGuard support.

### Keyboard shortcuts

Since FreeNet is a menu bar app (no Dock icon), standard shortcuts are handled internally:

| Shortcut | Action |
|----------|--------|
| `Cmd+Q` | Quit FreeNet (stops engine first) |
| `Cmd+,` | Open Settings |

## Architecture

```
FreeNet/
├── App/              # Entry point, global state, keyboard shortcuts
├── Views/            # SwiftUI — menu bar, dashboard, settings, setup wizard, about
│   ├── MenuBarView     # Connection toggle, live duration, engine status, first-run tip
│   ├── SetupWizard     # 6-step onboarding with VPN provider tutorials
│   ├── DashboardView   # Live traffic + learned domains
│   ├── SettingsView    # DNS, VPN, safelist, intelligence, general
│   ├── AboutView       # App info, version, links
│   └── LearnedDomainsView # Domain list with filters + sort
├── Engine/           # Mihomo process management, config generation, traffic monitor
├── Intelligence/     # Learning engine, failure detector, domain store, crowd client
├── Models/           # Domain state, traffic events, block reports
├── Helpers/          # WireGuard parser, DNS config, permissions
├── CLI/              # Command-line interface (ArgumentParser)
└── Resources/        # Mihomo binary, safe domain list, app icon

site/                 # Landing page (GitHub Pages)
freenet-api/          # Crowd intelligence API (Cloudflare Workers + D1)
```

### Tech stack

- **Proxy engine**: [Mihomo](https://github.com/MetaCubeX/mihomo) (embedded) -- routing, WireGuard, TUN, DNS interception
- **Intelligence**: Custom Swift layer -- failure detection, learning engine, SQLite domain store
- **Persistence**: [GRDB.swift](https://github.com/groue/GRDB.swift) (SQLite)
- **Config**: [Yams](https://github.com/jpsim/Yams) (YAML generation for Mihomo)
- **Crowd API**: [Hono](https://hono.dev) on Cloudflare Workers with D1
- **UI**: SwiftUI (native macOS)
- **CLI**: [ArgumentParser](https://github.com/apple/swift-argument-parser)

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
- Fully open source -- audit the code yourself

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

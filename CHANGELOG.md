# Changelog

All notable changes to FreeNet are documented here.

## [1.1.0] - 2026-03-08

### Added
- **6-step onboarding wizard**: Welcome, The Problem, How It Works, VPN Config, Permissions, All Set
- **VPN provider tutorials**: step-by-step setup guides for Proton VPN, Mullvad, Surfshark, NordVPN, Windscribe, and IVPN -- built into the wizard and on the website
- **About window**: app version, GitHub links, MIT license
- **Connection duration**: live uptime timer in the menu bar when connected
- **Engine startup progress**: real-time status messages during engine initialization
- **VPN-not-configured banner**: inline warning with setup link when VPN is missing
- **First-run tip**: one-time guidance after first connection
- **Quit button**: in menu bar footer, stops engine before exiting
- **Keyboard shortcuts**: Cmd+Q to quit, Cmd+, to open Settings (for LSUIElement apps)
- **Empty state messages**: helpful guidance in Dashboard and Learned Domains views
- **CLI module**: full command-line interface with start, stop, status, toggle, domains, traffic, sync, config, vpn commands

### Changed
- Onboarding trigger uses `hasCompletedOnboarding` (persisted) instead of VPN config presence
- Settings VPN section explains what you lose without VPN
- Settings uses `openWindow(id:)` instead of `showSetupWizard` flag
- Setup wizard window size bumped to 560x520
- Improved error messages during engine startup failures

### Fixed
- Replaced unsafe force unwraps on `FileManager.urls().first!` with proper error handling
- Menu bar Cmd+Q properly dispatches to main actor

## [1.0.0] - 2026-03-04

### Added
- Initial release
- Intelligent routing: encrypted DNS (default), VPN (blocked sites), direct (banking/DNS-hostile)
- System-wide ad blocking via DNS
- Learning engine with failure detection (TCP RST, DNS failure, TLS, HTTP 451, timeouts)
- WireGuard VPN integration (drop any .conf file)
- Crowd intelligence (anonymous block reporting and syncing)
- SQLite domain store with pre-seeded India safelist
- Menu bar app with live traffic monitoring
- Dashboard with traffic table and learned domains
- Settings: DNS provider, VPN config, safelist, notifications
- Landing page with GitHub Pages deployment
- Homebrew cask
- GitHub Actions release workflow (build + DMG)
- MIT license

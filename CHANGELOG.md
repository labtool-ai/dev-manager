# Changelog
All notable changes to DevManager. Downloads: [Releases](https://github.com/labtool-ai/dev-manager/releases)

## 0.1.6 — 2026-07-21

### Changed
- Copying a project path now yields the full absolute path (~ expanded), ready to paste into a terminal.
- Every start/restart begins with a clean log instead of appending to the previous run; logs still remain after a process exits so you can review a crash.

### Fixed
- Buttons are fully clickable: borderless buttons only registered hits on the glyphs themselves, so the padding did nothing (most visible on the segmented controls in Settings). Now the whole area responds, with a pressed-state fade.
- Sidebar collapse state persists: collapsing a group then visiting Settings or relaunching no longer expands everything again.

## 0.1.5 — 2026-07-21

### Added
- Rename a group: right-click a sidebar group (or use its ⋯ menu) to rename it — the tag changes across every project in that group.
- Right-click and double-click on projects: context menu with start/stop, restart, edit, reveal in Finder and delete (with confirmation); double-click opens the editor, matching Profiles.
- Drag projects between groups: drop onto another group's header or a project inside it to move it there (the header highlights); drop on Untagged to clear its group. Emptied groups disappear on their own.
- ⌘F focuses the log filter for live filtering, with one-click clear.

### Changed
- URL detection now recognizes http://0.0.0.0:PORT (Flask, Docker, vite --host) and normalizes it to localhost.

## 0.1.4 — 2026-07-08

### Added
- One-click copy for path and cmd, with a checkmark confirmation.
- Smarter port-conflict dialog: jump straight to the occupying project when it's one of yours, plus a Start anyway option that lets the dev server's own port fallback take over.

### Changed
- Profiles now start as an orchestrated sequence: each project waits until it's actually ready (port up / detected) before the next one starts, with a timeout fallback — ideal for db → api → web chains.

## 0.1.3 — 2026-07-06

### Added
- Resource sparklines and alerts: live CPU/memory mini-charts in the project detail, with configurable thresholds that trigger a notification.
- Smarter LAN QR: the actual listening port is detected automatically, and the QR only appears when the server is really reachable on the LAN. Bound to localhost only? You get instructions to expose it instead of a dead QR.

### Changed
- Deeper MCP: new list_ports and health tools, incremental get_logs via a since cursor, and cpu / mem / uptime in project listings.

## 0.1.2 — 2026-07-06

### Added
- Ports page: see every listening TCP port on your machine with its process and PID, marked when it's one this app started — open it or kill it right there.

### Changed
- Quitting the app now terminates the processes it started, so nothing is left orphaned.

## 0.1.1 — 2026-07-06

### Fixed
- Usage stats no longer undercount: quitting the app used to discard the currently running session, so total runtime was short. It's now recorded on quit, and in-progress runtime counts toward the totals.

## 0.2.0 — 2026-07-04

> Historical entry: these features shipped inside the first public 0.1.0 build.

### Added
- Port conflict detection: probe the port before start, tell whether it's one of this app's projects or an external process, then stop the occupier and start — never a blind kill.
- ⌘K quick-launch palette + ⌘⌥K global hotkey: fuzzy-search projects anywhere, enter to start/stop.
- Startup profiles: name a set of projects (across tags) and start them all in order with one click.
- package.json script import: pick a folder to list its scripts, detect npm / pnpm / yarn / bun, click to add as commands.
- Merged log stream: all running projects' output in one view, color-coded per project, filterable.
- Crash / ready notifications: get a system notification when a process crashes or a port first goes ready (toggle in settings).
- LAN URL + QR: the detail view shows a LAN address and QR while running — scan on a phone on the same Wi-Fi.
- Sidebar search + drag-to-reorder; and this changelog page.

### Changed
- The stop button is now solid/inverted while running; logs force color so vite/npm ANSI output renders properly.
- The stats heatmap now fits the full width responsively; the top toolbar is steadier when toggling the sidebar.

## 0.1.0 — 2026-07-04

### Added
- First release: menu-bar + main-window, real dev-process start/stop, live log stream, neutral-gray theme.
- Port-ready detection + click-to-open in browser; auto-restart on crash; start/stop a whole tag group.
- Usage stats: launch-activity heatmap, streaks, most-used projects, CPU/mem/uptime.
- Sparkle auto-update + bilingual (中/EN) settings.

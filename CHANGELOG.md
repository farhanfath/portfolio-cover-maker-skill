# Changelog

All notable changes to this skill are documented here.

The version that matters is the one in `.claude-plugin/plugin.json` — Claude Code only
offers users an update when that field changes, so it gets bumped on every release.

## [0.1.0] — 2026-08-25

First release.

### Added
- Seven layout archetypes: `solo`, `duo`, `split-right`, `split-left`, `centered`,
  `diagonal`, `scatter`, with automatic selection from screen count.
- OKLCH palette derived from the dominant hue of the screenshots, with a contrast
  invariant so text stays readable over whatever colour comes out.
- Headless render pipeline producing 3200×1800 PNGs plus self-contained HTML pages that
  still work when no browser is installed.
- `cover.json` validation with field-specific messages, hard limits on `screens` and
  `tagline`, and soft trimming with warnings for `name`, `badges`, and `meta`.
- Two install paths: a Claude Code plugin (`/plugin install`), and `npx
  project-cover-maker` for clients without a plugin system. The npx installer has no
  dependencies and refuses to overwrite a directory that holds someone else's skill.
- adb capture protocol for projects that ship no screenshots.
- Fixture-based end-to-end tests asserting output count, file size, and dimensions.

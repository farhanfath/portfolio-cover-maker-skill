# Project Cover Maker

An agent skill that turns a mobile app project into portfolio cover images.

Point your coding agent at your app repo. It finds your screenshots, picks the good ones,
derives a colour palette from the screenshots themselves, and renders up to four
**3200×1800 PNG** covers — phone mockups, project name, tagline, the lot.

Works with Claude Code, Codex, Cursor, OpenCode, and anything else that reads a skills
directory. No design tool, no API key, no build step, no dependencies — all it needs is a
Chromium-based browser already on your machine.

---

## What it makes

![Bank Sampah portfolio cover, split-left layout](https://raw.githubusercontent.com/farhanfath/portfolio-cover-maker-skill/main/docs/preview/split-left.webp)

Four variants come out of a single run — same screenshots, same derived palette,
different composition. Pick the one that fits where you're posting it:

|  |  |  |
|:--:|:--:|:--:|
| ![split-right layout](https://raw.githubusercontent.com/farhanfath/portfolio-cover-maker-skill/main/docs/preview/split-right.webp) | ![centered layout](https://raw.githubusercontent.com/farhanfath/portfolio-cover-maker-skill/main/docs/preview/centered.webp) | ![solo layout](https://raw.githubusercontent.com/farhanfath/portfolio-cover-maker-skill/main/docs/preview/solo.webp) |
| `split-right` | `centered` | `solo` |

<sub>Real output, not a mockup: an Android waste-bank app, built from nine screenshots
sitting in its `demo/` folder. The green palette was read off the screenshots — nothing
about it was configured by hand.</sub>

## Install

### Claude Code — as a plugin

```
/plugin marketplace add farhanfath/portfolio-cover-maker-skill
/plugin install project-cover-maker@farhanfath-skills
```

Worth preferring if you're on Claude Code: it keeps itself up to date, and nothing
lands in your project.

### Every other agent — npx

Codex, Cursor, OpenCode, Claude Desktop, and anything else that reads a skills
directory, via the [`skills`](https://github.com/vercel-labs/skills) CLI:

```bash
npx skills add https://github.com/farhanfath/portfolio-cover-maker-skill
```

Add `-g` to install globally instead of into the current project, `-a <agent>` to pick
which agents get it. Update later with `npx skills update`, remove with
`npx skills remove`.

<details>
<summary>Or just clone it</summary>

```bash
git clone https://github.com/farhanfath/portfolio-cover-maker-skill.git
cp -r portfolio-cover-maker-skill/skills/project-cover-maker <your-skills-dir>/
```

Copy the inner `skills/project-cover-maker/` directory, not the repo — the repo root
holds the tests and manifests, and a skills directory expects `SKILL.md` at the top.

Where `<your-skills-dir>` is whatever your agent reads: `~/.claude/skills` for Claude,
`~/.codex/skills` for Codex, `~/.opencode/skills` for OpenCode, or `.claude/skills` in a
project for any of them. `npx skills add` figures this out for you, which is why it's
the easier path.
</details>

## Requirements

Chrome, Chromium, or Edge installed. Nothing else.

Without a browser the skill still emits self-contained HTML pages you can open and
screenshot yourself, so it never leaves you empty-handed.

## Use it

From inside your app project:

```
> buatin cover portfolio buat project ini
```

or

```
> make me a portfolio cover for this app
```

The agent will:

1. **Find your material** — looks in `screenshots/`, `docs/screenshots/`,
   `assets/screenshots/`, `docs/`, `example/`, then the repo root. Also hunts for a logo
   and reads your `README.md`, `pubspec.yaml`, `build.gradle`, or `package.json` for the
   app name.
2. **Actually look at the screenshots** — and throw out the duplicates, empty splashes,
   error dialogs, and anything with the keyboard open. It picks the strongest 3–5 and
   marks one as the hero.
3. **Write a `cover.json`** next to your screenshots.
4. **Render** — up to four layout variants in one pass.
5. **Look at the results** and fix what's broken (overflowing name, colliding tagline,
   weak contrast), then re-render. Max two correction rounds.
6. **Hand you the files** with a note on which layout suits what.

Output lands in `cover-output/` next to your `cover.json`, not in the skill folder.

No screenshots at all? It will offer to capture them over `adb` — and it will ask you
to drive the app, not navigate it blindly.

## Layouts

Seven archetypes, picked automatically from how many screens you have:

| Layout | Min screens | Feel |
|---|---|---|
| `solo` | 1 | One big tilted phone, large type |
| `duo` | 2 | A pair, side by side |
| `split-right` | 2 | Copy left, phones right — the default |
| `split-left` | 2 | Mirrored; suits long names and taglines |
| `centered` | 3 | Symmetric, logo-forward |
| `diagonal` | 3 | Angled cascade — opt-in, not automatic |
| `scatter` | 5 | Loose spread for screenshot-rich apps |

You can pin one explicitly to render a single file — the cheapest way to iterate.

## `cover.json`

Written for you, but here's the shape if you want to hand-tune it:

```json
{
  "project": { "name": "TripMate", "tagline": "Your smart travel assistant", "logo": null },
  "screens": [
    { "src": "home.png",   "role": "hero" },
    { "src": "chat.png",   "role": "support" },
    { "src": "detail.png", "role": "support" }
  ],
  "badges": [],
  "meta": null,
  "layout": "auto",
  "palette": { "mode": "auto" },
  "decor": "auto",
  "output": { "dir": "cover-output", "scale": 2 }
}
```

**Hard limits** (the file is rejected): 1–6 `screens` with exactly one `hero`; `tagline`
at most 64 characters.

**Soft limits** (trimmed with a warning): `name` over 16 characters shrinks the wordmark;
`badges` past the first 4 are dropped; `meta` is cut to 12 characters.

`src` paths are relative to `cover.json`. So is `output.dir`.

### Rendering by hand

```bash
bash skills/project-cover-maker/scripts/render.sh path/to/cover.json
powershell -File skills\project-cover-maker\scripts\render.ps1 path\to\cover.json
```

From an installed copy, that's `<skills-dir>/project-cover-maker/scripts/render.sh`.

## Scope

**Mobile apps only.** The device frame is a phone, and that is the whole premise. Web
apps, dashboards, CLI tools, ML projects, and backends are out of scope — you'll get a
phone mockup of something that isn't a phone app, which helps nobody.

## Updates

Installed as a plugin, Claude Code checks in the background and offers you the new
version. To pull one immediately:

```
/plugin marketplace update farhanfath-skills
```

Installed through the `skills` CLI, run `npx skills update`.

What changed in each release is in [CHANGELOG.md](CHANGELOG.md).

## Layout of this repo

```
skills/project-cover-maker/     everything that ships to a user
  SKILL.md                      the agent-facing instructions
  assets/                       CSS, JS, fonts, decorative SVGs — the renderer
  scripts/render.{sh,ps1}       builds a self-contained page, screenshots it headless
  references/layouts.md         anatomy of all seven archetypes
  references/capture-adb.md     the adb capture protocol
  example/                      reference covers the archetypes were designed against

.claude-plugin/                 plugin and marketplace manifests
docs/preview/                   the sample output shown above
tests/                          fixture-based end-to-end render tests
```

The `skills/<name>/` nesting is what draws the line between the skill and its
repository. Both installers copy that directory and nothing above it, so `tests/`,
`docs/`, and the manifests stay out of what lands on a user's machine — no ignore file
involved. Anything the skill reads at runtime has to live inside it.

Run the tests with `bash tests/run.sh` or `powershell -File tests\run.ps1`.

To cut a release, bump `version` in `.claude-plugin/plugin.json` — Claude Code only
offers users an update when that field changes.

## License

MIT — see [LICENSE](LICENSE).

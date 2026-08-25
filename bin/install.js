#!/usr/bin/env node
'use strict';

// Installer for people who don't use the Claude Code plugin system: copies the
// skill into a skills directory that any Claude client already reads. Zero
// dependencies on purpose - the skill itself needs nothing but a browser, and
// an installer that drags in a dependency tree would be the heaviest part of
// the whole package.

const fs = require('fs');
const os = require('os');
const path = require('path');

const SKILL_NAME = 'project-cover-maker';
const PKG_ROOT = path.join(__dirname, '..');

// Everything the skill needs at runtime. This list is the check on package.json's
// "files" field: if npm ever ships a partial tarball, the install aborts here
// with the missing path named, instead of landing a skill that fails later at
// render time with a confusing "no such file".
const PAYLOAD = ['SKILL.md', 'assets', 'scripts', 'references', 'example'];

const argv = process.argv.slice(2);
const has = (flag) => argv.includes(flag);
const valueOf = (flag) => {
  const i = argv.indexOf(flag);
  return i >= 0 ? argv[i + 1] : undefined;
};

function version() {
  try {
    return JSON.parse(fs.readFileSync(path.join(PKG_ROOT, 'package.json'), 'utf8')).version;
  } catch {
    return 'unknown';
  }
}

function usage() {
  console.log(`
  project-cover-maker ${version()}

  Installs the cover-maker skill into a Claude skills directory.

    npx project-cover-maker              install for the current user
                                         (~/.claude/skills/${SKILL_NAME})
    npx project-cover-maker --project    install into this project only
                                         (./.claude/skills/${SKILL_NAME})
    npx project-cover-maker --dir <path> install into an exact directory

    --force    overwrite the target even if something unrelated is there
    --help     show this

  Using Claude Code? The plugin install is better - it updates itself:

    /plugin marketplace add farhanfath/portfolio-cover-maker-skill
    /plugin install ${SKILL_NAME}@farhanfath-skills
`);
}

function resolveTarget() {
  const custom = valueOf('--dir');
  if (custom) return path.resolve(custom);
  const base = has('--project')
    ? path.join(process.cwd(), '.claude', 'skills')
    : path.join(os.homedir(), '.claude', 'skills');
  return path.join(base, SKILL_NAME);
}

// Never overwrite blind. A skills directory is the user's, and a name collision
// here is far likelier to be someone else's skill than a stale copy of ours.
function inspectTarget(dir) {
  if (!fs.existsSync(dir)) return { kind: 'new' };
  const skillFile = path.join(dir, 'SKILL.md');
  if (!fs.existsSync(skillFile)) return { kind: 'foreign', why: 'it has no SKILL.md' };
  const head = fs.readFileSync(skillFile, 'utf8').slice(0, 500);
  const match = head.match(/^name:\s*(.+)$/m);
  const found = match ? match[1].trim() : null;
  if (found === SKILL_NAME) return { kind: 'ours' };
  return { kind: 'foreign', why: found ? `it holds the skill "${found}"` : 'its SKILL.md has no name' };
}

function main() {
  if (has('--help') || has('-h')) return usage();

  const missing = PAYLOAD.filter((p) => !fs.existsSync(path.join(PKG_ROOT, p)));
  if (missing.length) {
    console.error(`error: this package is incomplete - missing ${missing.join(', ')}`);
    console.error('       nothing was installed. Please report this at');
    console.error('       https://github.com/farhanfath/portfolio-cover-maker-skill/issues');
    process.exit(1);
  }

  const target = resolveTarget();
  const state = inspectTarget(target);

  if (state.kind === 'foreign' && !has('--force')) {
    console.error(`error: ${target}`);
    console.error(`       already exists and does not look like this skill (${state.why}).`);
    console.error('       Nothing was changed. Pass --force to overwrite it, or --dir to');
    console.error('       install somewhere else.');
    process.exit(1);
  }

  fs.mkdirSync(target, { recursive: true });
  for (const item of PAYLOAD) {
    const dest = path.join(target, item);
    fs.rmSync(dest, { recursive: true, force: true });
    fs.cpSync(path.join(PKG_ROOT, item), dest, { recursive: true });
  }

  const verb = state.kind === 'ours' ? 'Updated' : 'Installed';
  console.log(`\n  ${verb} ${SKILL_NAME} ${version()}`);
  console.log(`  ${target}\n`);
  console.log('  Ask Claude for a portfolio cover from inside a mobile app project.');
  console.log('  Needs Chrome, Chromium, or Edge on your machine - nothing else.\n');
  console.log(`  To remove it later, delete that directory.\n`);
}

main();

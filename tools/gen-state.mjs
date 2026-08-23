#!/usr/bin/env node
/**
 * Generates the GDScript and TypeScript views of shared/state.json.
 * This is based upon bf6 typescript <-> gdscript , as well as some other converters.
 * 
 * This is just a scoped and tree shaken version of the converter. 
 * 
 * DO NOT EDIT THIS UNLESS USING SOMETHING LIKE TinyTemplate Syntax
 * 
 * Bitty shift layout is our safe to share via (FFI / aka language boundary) -> exactly one
 * file defines the values amoung ts, js, gdscript.
 * 
 * Editing any generated file (by hand) could cause a build failure but prevent a silent divergence.
 *
 * Usage via node tools/gen-state.mjs [--check? --proto?]
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const spec = JSON.parse(readFileSync(join(root, 'shared/state.json'), 'utf8'));
const check = process.argv.includes('--check');

const BANNER = [
  'GENERATED FILE - DO NOT EDIT.',
  '',
  'Source: shared/state.json',
  'Regenerate: npm run gen:state (from vite/)',
];

function snake(name) {
  return name.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
}

function lower(name) {
  return name.charAt(0).toLowerCase() + name.slice(1);
}

function constPrefix(name) {
  return name.replace(/Flags$/, '').toUpperCase();
}

function wrapDoc(text, prefix, width = 88) {
  const out = [];
  for (const line of text.split('\n')) {
    let current = '';
    for (const word of line.split(' ')) {
      if (current && (prefix + current + ' ' + word).length > width) {
        out.push(prefix + current);
        current = word;
      } else {
        current = current ? current + ' ' + word : word;
      }
    }
    out.push(prefix + current);
  }
  return out;
}

function gdscript() {
  const L = ['class_name StateBits', ''];
  L.push(...BANNER.map((l) => (l ? `## ${l}` : '##')));
  L.push('');
  for (const [name, def] of Object.entries(spec.enums ?? {})) {
    L.push(...wrapDoc(def.description, '## '));
    L.push(`enum ${name} {`);
    for (const [key, value] of Object.entries(def.values)) L.push(`\t${key} = ${value},`);
    L.push('}', '');
  }
  for (const [name, def] of Object.entries(spec.flags ?? {})) {
    L.push(...wrapDoc(def.description, '## '));
    for (const [key, bit] of Object.entries(def.bits)) {
      L.push(`const ${constPrefix(name)}_${key} := 1 << ${bit}`);
    }
    L.push('');
  }

  L.push('## True when every bit in [param flags] is set in [param value].');
  L.push('static func has_all(value: int, flags: int) -> bool:');
  L.push('\treturn (value & flags) == flags', '');
  L.push('## True when any bit in [param flags] is set in [param value].');
  L.push('static func has_any(value: int, flags: int) -> bool:');
  L.push('\treturn (value & flags) != 0', '');

  L.push('# Debug decoders. A packed int is unreadable in a log or a breakpoint, which is');
  L.push('# the one real cost of packing state - so the names travel with the layout and');
  L.push('# are generated from the same source rather than retyped.');
  L.push('');
  for (const [name, def] of Object.entries(spec.enums ?? {})) {
    const fn = snake(name);
    const pairs = Object.entries(def.values).map(([k, v]) => `${v}: "${k}"`).join(', ');
    L.push(`const _${fn.toUpperCase()}_NAMES := {${pairs}}`);
    L.push(`## Human-readable name for a [enum ${name}] value.`);
    L.push(`static func ${fn}_name(value: int) -> String:`);
    L.push(`\treturn _${fn.toUpperCase()}_NAMES.get(value, "UNKNOWN(%d)" % value)`, '');
  }
  for (const [name, def] of Object.entries(spec.flags ?? {})) {
    const fn = snake(name);
    const pairs = Object.entries(def.bits).map(([k, b]) => `${1 << b}: "${k}"`).join(', ');
    L.push(`const _${fn.toUpperCase()}_NAMES := {${pairs}}`);
    L.push(`## Renders a packed [code]${name}[/code] value as "ALIVE|MOVING", or "NONE".`);
    L.push(`static func describe_${fn}(value: int) -> String:`);
    L.push('\tvar parts: PackedStringArray = []');
    L.push(`\tfor bit: int in _${fn.toUpperCase()}_NAMES:`);
    L.push('\t\tif value & bit:');
    L.push(`\t\t\tparts.append(_${fn.toUpperCase()}_NAMES[bit])`);
    L.push('\tvar known: int = 0');
    L.push(`\tfor bit: int in _${fn.toUpperCase()}_NAMES:`);
    L.push('\t\tknown |= bit');
    L.push('\tif value & ~known:');
    L.push('\t\tparts.append("UNKNOWN(0x%x)" % (value & ~known))');
    L.push('\treturn "|".join(parts) if not parts.is_empty() else "NONE"', '');
  }
  return L.join('\n').replace(/\n+$/, '\n');
}

function typescript() {
  const L = ['/**', ...BANNER.map((l) => (l ? ` * ${l}` : ' *')), ' */', ''];
  const doc = (text) => L.push('/**', ...wrapDoc(text, ' * '), ' */');

  for (const [name, def] of Object.entries(spec.enums ?? {})) {
    doc(def.description);
    L.push(`export const ${name} = {`);
    for (const [key, value] of Object.entries(def.values)) L.push(`  ${key}: ${value},`);
    L.push('} as const;');
    L.push(`export type ${name} = (typeof ${name})[keyof typeof ${name}];`, '');
  }
  for (const [name, def] of Object.entries(spec.flags ?? {})) {
    doc(def.description);
    L.push(`export const ${name} = {`);
    for (const [key, bit] of Object.entries(def.bits)) L.push(`  ${key}: 1 << ${bit},`);
    L.push('} as const;');
    L.push(`export type ${name} = (typeof ${name})[keyof typeof ${name}];`, '');
  }

  L.push('/** True when every bit in `flags` is set in `value`. */');
  L.push('export const hasAll = (value: number, flags: number): boolean => (value & flags) === flags;', '');
  L.push('/** True when any bit in `flags` is set in `value`. */');
  L.push('export const hasAny = (value: number, flags: number): boolean => (value & flags) !== 0;', '');

  L.push('/*');
  L.push(' * Debug decoders. A packed int is unreadable in devtools, ');
  L.push(' * thus the names travel with the layout and are generated');
  L.push(' * from the same source (as the GDScript side rather than retyped like a monkey press.)');
  L.push(' */');
  L.push('');
  for (const [name, def] of Object.entries(spec.enums ?? {})) {
    const pairs = Object.entries(def.values).map(([k, v]) => `${v}: '${k}'`).join(', ');
    L.push(`const ${lower(name)}Names: Record<number, string> = { ${pairs} };`);
    doc(`Human-readable name for a \`${name}\` value.`);
    L.push(`export const ${lower(name)}Name = (value: number): string =>`);
    L.push(`  ${lower(name)}Names[value] ?? \`UNKNOWN(\${value})\`;`, '');
  }
  for (const [name, def] of Object.entries(spec.flags ?? {})) {
    const pairs = Object.entries(def.bits).map(([k, b]) => `${1 << b}: '${k}'`).join(', ');
    L.push(`const ${lower(name)}Names: Record<number, string> = { ${pairs} };`);
    doc(`Renders a packed \`${name}\` value as "ALIVE|MOVING", or "NONE".`);
    L.push(`export const describe${name} = (value: number): string => {`);
    L.push(`  const parts = Object.entries(${lower(name)}Names)`);
    L.push('    .filter(([bit]) => value & Number(bit))');
    L.push('    .map(([, label]) => label);');
    L.push(`  const known = Object.keys(${lower(name)}Names).reduce((a, b) => a | Number(b), 0);`);
    L.push('  const rest = value & ~known;');
    L.push('  if (rest) parts.push(`UNKNOWN(0x${rest.toString(16)})`);');
    L.push("  return parts.length ? parts.join('|') : 'NONE';");
    L.push('};', '');
  }
  return L.join('\n').replace(/\n+$/, '\n');
}

/* targets are just two for this scope */
const targets = [
  ['godot/scripts/ecs/state_bits.gd', gdscript()],
  ['vite/src/godot/state.ts', typescript()],
];

let stale = false;
for (const [rel, content] of targets) {
  const path = join(root, rel);
  if (check) {
    let existing = '';
    try {
      existing = readFileSync(path, 'utf8');
    } catch {
      /* missing counts as stale, should eventually trigger an issue ticket */
    }
    if (existing !== content) {
      console.error(`stale: ${rel}`);
      stale = true;
    }
  } else {
    writeFileSync(path, content);
    console.log(`wrote ${rel}`);
  }
}

if (check && stale) {
  console.error('\nshared/state.json changed without regenerating; resolve via npm run gen:state');
  process.exit(1);
}
if (check) console.log('hell ya brother, generated state files are up to date');

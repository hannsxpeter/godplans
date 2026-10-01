#!/usr/bin/env node
'use strict';

// Parity checks for scripts/lint.sh, kept in a file so js-syntax and node
// --check cover them. lint.sh owns the reporting; this prints data only.
//
//   node scripts/lint-parity.js description-length
//     prints the SKILL.md description length in characters.
//   node scripts/lint-parity.js description-parity
//     prints one line per plugin manifest whose description differs.
//   node scripts/lint-parity.js domain-parity "CONTRACT MODULES"
//     prints "domains N M" (N domain modules, M lists compared), then one
//     "problem TEXT" line per disagreement.
//
// A read or parse error exits 2 with the reason on stderr.

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const skillRel = 'skills/godplans/SKILL.md';
const refsRel = 'skills/godplans/references';
const validatorRel = 'skills/godplans/scripts/validate-plan.sh';
const buildRel = 'scripts/build-prompt.sh';
const metricsRel = 'scripts/context-metrics.js';
const portableRel = 'tests/portable-prompt.test.sh';
const templateRel = 'skills/godplans/templates/PLAN.template.mdx';
const discoveryRel = 'skills/godplans/references/discovery.md';
const schemaRel = 'skills/godplans/schemas/PLAN.schema.json';

function die(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function read(rel) {
  const file = path.join(root, rel);
  if (!fs.existsSync(file)) throw new Error(`${rel} does not exist`);
  return fs.readFileSync(file, 'utf8');
}

function readJson(rel) {
  const text = read(rel);
  try {
    return JSON.parse(text);
  } catch (error) {
    die(`${rel} is not valid JSON: ${error.message}`);
  }
  return null;
}

// The description must be one double-quoted line, which is also a JSON
// string, so JSON.parse reads it exactly. Folded, literal, plain, and
// multi-line forms are refused rather than parsed: YAML folding rules are
// easy to get subtly wrong, and one form is enough.
function description() {
  const lines = read(skillRel).split(/\r?\n/);
  if (lines[0] !== '---') die(`${skillRel} does not start with a --- frontmatter line`);
  const close = lines.indexOf('---', 1);
  if (close < 0) die(`${skillRel} frontmatter has no closing --- line`);
  const line = lines.slice(1, close).find((text) => /^description:/.test(text));
  if (line === undefined) die(`${skillRel} frontmatter has no description`);
  const quoted = line.match(/^description:[ \t]*("(?:[^"\\]|\\.)*")[ \t]*$/);
  if (!quoted) die(`${skillRel} description must be one double-quoted line (no >, |, plain, or continued form)`);
  try {
    return JSON.parse(quoted[1]);
  } catch (error) {
    die(`${skillRel} description uses an escape JSON cannot read: ${error.message}`);
  }
  return '';
}

function descriptionParity(value) {
  const problems = [];
  const compare = (label, actual) => {
    if (typeof actual !== 'string') {
      problems.push(`${label} has no description string`);
      return;
    }
    if (actual === value) return;
    let at = 0;
    while (at < actual.length && at < value.length && actual[at] === value[at]) at += 1;
    problems.push(`${label} description differs from the SKILL.md frontmatter description at character ${at + 1} (${actual.length} vs ${value.length} characters); copy the SKILL.md description into it verbatim`);
  };
  const pluginRel = 'plugins/godplans/.claude-plugin/plugin.json';
  compare(pluginRel, readJson(pluginRel).description);
  const marketRel = '.claude-plugin/marketplace.json';
  const market = readJson(marketRel);
  const entries = Array.isArray(market.plugins) ? market.plugins.filter((entry) => entry && entry.name === 'godplans') : [];
  if (entries.length !== 1) {
    problems.push(`${marketRel} has ${entries.length} plugin entries named godplans; want exactly 1`);
  } else {
    compare(`${marketRel} godplans plugin entry`, entries[0].description);
  }
  return problems;
}

function words(text) {
  return text.split(/\s+/).filter(Boolean);
}

function quotedStrings(text) {
  return Array.from(text.matchAll(/(['"])([^'"]+)\1/g), (match) => match[2]);
}

function need(match, what) {
  if (!match) throw new Error(`cannot find ${what}`);
  return match;
}

// Perl hash pairs: 'key' => 'value' or KEY => 'value'.
function perlPairs(text) {
  return Array.from(text.matchAll(/(['"]?)([A-Za-z0-9_-]+)\1\s*=>\s*(['"])([^'"]+)\3/g), (pair) => [pair[2], pair[4]]);
}

// The R-<PREFIX>-N ids a module defines: those that start a line (after an
// optional list marker) inside its ## Plan requirements section. Ids cited
// mid-sentence are cross-references to other modules and are not counted.
function definedPrefixes(text) {
  const prefixes = new Set();
  let inside = false;
  for (const line of text.split(/\r?\n/)) {
    if (/^## Plan requirements\s*$/.test(line)) {
      inside = true;
      continue;
    }
    if (inside && /^## /.test(line)) inside = false;
    if (!inside) continue;
    const id = line.match(/^\s*(?:(?:[0-9]+\.|[-*])\s+)?(?:\*\*)?R-([A-Z][A-Z0-9-]*)-[0-9]+/);
    if (id) prefixes.add(id[1]);
  }
  return prefixes;
}

function domainParity(contractText) {
  const contract = new Set(words(contractText || ''));
  const problems = [];
  const domains = fs.readdirSync(path.join(root, refsRel))
    .filter((name) => name.endsWith('.md'))
    .map((name) => name.slice(0, -3))
    .filter((name) => !contract.has(name))
    .sort();
  if (domains.length === 0) problems.push(`${refsRel} has no domain modules`);
  const isDomain = (name) => !contract.has(name);

  // compare: NAMES must hold each EXPECTED name exactly once and nothing else.
  const compare = (label, names, expected, lacks, extra) => {
    const counts = new Map();
    for (const name of names) counts.set(name, (counts.get(name) || 0) + 1);
    for (const name of expected) {
      if (!counts.has(name)) problems.push(lacks(name));
    }
    for (const [name, count] of counts) {
      if (!expected.includes(name)) problems.push(extra(name));
      if (count > 1) problems.push(`${label} names ${name} ${count} times`);
    }
  };
  const compareToDomains = (label, names) => compare(label, names, domains,
    (name) => `${label} lacks domain module ${name}`,
    (name) => `${label} names ${name}, but ${refsRel}/${name}.md does not exist`);

  // Read every source once. A source whose shape cannot be found is one
  // problem, and the checks that need it are skipped.
  const texts = {};
  for (const rel of [skillRel, validatorRel, buildRel, metricsRel, portableRel, templateRel, discoveryRel, schemaRel]) {
    try {
      texts[rel] = read(rel);
    } catch (error) {
      problems.push(error.message);
    }
  }
  const extract = (label, rel, fn) => {
    if (texts[rel] === undefined) return null;
    try {
      return fn(texts[rel]);
    } catch (error) {
      problems.push(`${label}: ${error.message}`);
      return null;
    }
  };

  const phase4 = extract(`${skillRel} Phase 4 table`, skillRel, (text) => {
    const lines = text.split(/\r?\n/);
    const start = lines.findIndex((line) => /^### Phase 4\b/.test(line));
    if (start < 0) throw new Error('cannot find the "### Phase 4" heading');
    const names = [];
    for (let i = start + 1; i < lines.length && !/^#{1,3} /.test(lines[i]); i += 1) {
      if (!lines[i].startsWith('|')) continue;
      for (const match of lines[i].matchAll(/references\/([a-z0-9-]+)\.md/g)) names.push(match[1]);
    }
    if (names.length === 0) throw new Error('the Phase 4 table names no references/<module>.md');
    return names;
  });
  const knownDomain = extract(`${validatorRel} %known_domain`, validatorRel, (text) =>
    words(need(text.match(/%known_domain\s*=\s*map\s*\{[^}]*\}\s*qw\(([^)]*)\)/), 'the %known_domain qw() list')[1]));
  const modulePrefix = extract(`${validatorRel} %module_prefix`, validatorRel, (text) =>
    perlPairs(need(text.match(/%module_prefix\s*=\s*\(([\s\S]*?)\);/), 'the %module_prefix table')[1]));
  // The way back from a prefix to its module: either derived with reverse, or
  // a hand-written %requirement_domain table that must be the exact inverse.
  const requirementDomain = extract(`${validatorRel} prefix-to-module map`, validatorRel, (text) => {
    if (/%prefix_module\s*=\s*reverse\s+%module_prefix\s*;/.test(text)) return [];
    const table = text.match(/%requirement_domain\s*=\s*\(([\s\S]*?)\);/);
    if (!table) throw new Error('cannot find %prefix_module = reverse %module_prefix or a %requirement_domain table');
    return perlPairs(table[1]);
  });
  const orders = extract(`${buildRel} REFERENCE_ORDER`, buildRel, (text) => {
    const match = need(text.match(/if \[ "\$MODE" = "full" \]; then\s*\n\s*REFERENCE_ORDER="([^"]*)"\s*\nelse\s*\n\s*REFERENCE_ORDER="([^"]*)"/), 'the full and core REFERENCE_ORDER assignments');
    return { full: words(match[1]), core: words(match[2]) };
  });
  const fullCount = extract(`${buildRel} full-mode header`, buildRel, (text) =>
    Number(need(text.match(/\ball ([0-9]+) domain modules\b/), '"all N domain modules"')[1]));
  const lazySentence = extract(`${buildRel} core-mode lazy module sentence`, buildRel, (text) => {
    const match = need(text.replace(/\s+/g, ' ').match(/The lazy modules are ([^.]*)\./), '"The lazy modules are ..."');
    return match[1].split(/\s*,\s*(?:and\s+)?|\s+and\s+/).filter(Boolean);
  });
  const metrics = extract(`${metricsRel} module lists`, metricsRel, (text) => ({
    core: quotedStrings(need(text.match(/const coreModules = \[([\s\S]*?)\];/), 'const coreModules = [...]')[1]),
    lazy: quotedStrings(need(text.match(/const lazyModules = \[([\s\S]*?)\];/), 'const lazyModules = [...]')[1]),
  }));
  // A plan copies the template's matrix and the discovery module shows a worked
  // one; the validator fails any plan whose matrix lacks a known domain, so a
  // row missing here reaches every plan an agent writes from these examples.
  const matrixRows = (text) => {
    const lines = text.split(/\r?\n/);
    const start = lines.findIndex((line) => line === '## Applicability matrix');
    if (start < 0) throw new Error('cannot find the "## Applicability matrix" heading');
    const names = [];
    for (let i = start + 1; i < lines.length && !/^#{1,3} /.test(lines[i]) && !lines[i].startsWith('```'); i += 1) {
      const row = lines[i].match(/^\|\s*([a-z][a-z0-9-]*)\s*\|/);
      if (row) names.push(row[1]);
    }
    if (names.length === 0) throw new Error('the applicability matrix has no domain rows');
    return names;
  };
  const templateMatrix = extract(`${templateRel} applicability matrix`, templateRel, matrixRows);
  const discoveryMatrix = extract(`${discoveryRel} worked applicability matrix`, discoveryRel, matrixRows);
  const schemaCount = extract(`${schemaRel} applicability count`, schemaRel, (text) => {
    const applicability = need(JSON.parse(text).properties || null, 'top-level properties').applicability;
    need(applicability, 'properties.applicability');
    return { min: applicability.minItems, max: applicability.maxItems };
  });
  const portable = extract(`${portableRel} module lists`, portableRel, (text) => ({
    core: words(need(text.match(/^expected_refs="([^"]*)"/m), 'expected_refs="..."')[1]),
    lazy: words(need(text.match(/^lazy_refs="([^"]*)"/m), 'lazy_refs="..."')[1]),
  }));

  // Every list names every domain module exactly once.
  const lists = [];
  if (phase4) lists.push([`${skillRel} Phase 4 table`, phase4]);
  if (knownDomain) lists.push([`${validatorRel} %known_domain`, knownDomain]);
  if (modulePrefix) lists.push([`${validatorRel} %module_prefix keys`, modulePrefix.map((pair) => pair[0])]);
  if (requirementDomain && requirementDomain.length) lists.push([`${validatorRel} %requirement_domain values`, requirementDomain.map((pair) => pair[1])]);
  if (orders) lists.push([`${buildRel} full REFERENCE_ORDER`, orders.full]);
  if (metrics) lists.push([`${metricsRel} coreModules + lazyModules`, metrics.core.concat(metrics.lazy)]);
  if (portable) lists.push([`${portableRel} expected_refs + lazy_refs`, portable.core.concat(portable.lazy)]);
  if (templateMatrix) lists.push([`${templateRel} applicability matrix`, templateMatrix]);
  if (discoveryMatrix) lists.push([`${discoveryRel} worked applicability matrix`, discoveryMatrix]);
  for (const [label, names] of lists) compareToDomains(label, names.filter(isDomain));
  if (schemaCount && (schemaCount.min !== domains.length || schemaCount.max !== domains.length)) {
    problems.push(`${schemaRel} applicability minItems ${schemaCount.min} and maxItems ${schemaCount.max} must both equal the ${domains.length} domain modules`);
  }

  // The core and lazy split agrees with context-metrics.js.
  if (metrics) {
    const core = metrics.core.filter(isDomain);
    const lazy = metrics.lazy.filter(isDomain);
    const split = [];
    if (orders) split.push([`${buildRel} core REFERENCE_ORDER`, orders.core, core, `${metricsRel} coreModules`]);
    if (lazySentence) split.push([`${buildRel} core-mode lazy module sentence`, lazySentence, lazy, `${metricsRel} lazyModules`]);
    if (portable) {
      split.push([`${portableRel} expected_refs`, portable.core, core, `${metricsRel} coreModules`]);
      split.push([`${portableRel} lazy_refs`, portable.lazy, lazy, `${metricsRel} lazyModules`]);
    }
    for (const [label, names, expected, expectedLabel] of split) {
      compare(label, names.filter(isDomain), expected,
        (name) => `${label} lacks ${name}, which ${expectedLabel} names`,
        (name) => `${label} names ${name}, which ${expectedLabel} does not`);
    }
  }

  if (fullCount !== null && fullCount !== domains.length) {
    problems.push(`${buildRel} full-mode header says all ${fullCount} domain modules, but ${refsRel} has ${domains.length}`);
  }

  // Prefixes: one per module, the inverse map agrees, and each module defines
  // its requirements under its own prefix.
  if (modulePrefix) {
    const prefixOf = new Map(modulePrefix);
    const owners = new Map();
    for (const [module, prefix] of modulePrefix) owners.set(prefix, (owners.get(prefix) || []).concat(module));
    for (const [prefix, modules] of owners) {
      if (modules.length > 1) problems.push(`${validatorRel} %module_prefix gives the prefix ${prefix} to ${modules.join(' and ')}`);
    }
    if (requirementDomain) {
      for (const [prefix, module] of requirementDomain) {
        if (prefixOf.get(module) !== prefix) problems.push(`${validatorRel} %requirement_domain maps ${prefix} to ${module}, but %module_prefix gives ${module} the prefix ${prefixOf.get(module) || '(none)'}`);
      }
      if (requirementDomain.length) {
        const mapped = new Set(requirementDomain.map((pair) => pair[0]));
        for (const [module, prefix] of modulePrefix) {
          if (!mapped.has(prefix)) problems.push(`${validatorRel} %requirement_domain has no entry for ${prefix}, the %module_prefix prefix of ${module}`);
        }
      }
    }
    for (const domain of domains) {
      const own = prefixOf.get(domain);
      if (!own) continue;
      const defined = definedPrefixes(read(`${refsRel}/${domain}.md`));
      if (!defined.has(own)) problems.push(`${refsRel}/${domain}.md defines no R-${own}-N requirement, but %module_prefix gives ${domain} the prefix ${own}`);
      for (const prefix of defined) {
        if (prefix !== own) problems.push(`${refsRel}/${domain}.md defines R-${prefix}-N requirements, but %module_prefix gives ${domain} the prefix ${own}`);
      }
    }
  }

  return { domains: domains.length, lists: lists.length, problems };
}

const mode = process.argv[2];
try {
  if (mode === 'description-length') {
    process.stdout.write(`${Array.from(description()).length}\n`);
  } else if (mode === 'description-parity') {
    process.stdout.write(descriptionParity(description()).map((line) => `${line}\n`).join(''));
  } else if (mode === 'domain-parity') {
    const result = domainParity(process.argv[3]);
    process.stdout.write(`domains ${result.domains} ${result.lists}\n`);
    process.stdout.write(result.problems.map((line) => `problem ${line}\n`).join(''));
  } else {
    die('usage: node scripts/lint-parity.js description-length | description-parity | domain-parity "CONTRACT MODULES"');
  }
} catch (error) {
  die(error.message);
}

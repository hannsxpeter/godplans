#!/usr/bin/env node
// Dependency-free JSON Schema subset checker for PLAN.json sidecars.
//
// Usage: node tests/lib/plan-schema-check.js SCHEMA.json DOCUMENT.json...
//
// It implements exactly the keywords PLAN.schema.json uses and throws on any
// other keyword, so a schema edit that relies on something unimplemented fails
// the suite instead of passing unchecked. Documents are decoded as strict UTF-8
// because a sidecar that is not valid UTF-8 is not valid JSON.

'use strict';

const fs = require('node:fs');

const ANNOTATIONS = new Set(['$schema', 'title', 'description']);
const KEYWORDS = new Set([
  'type', 'enum', 'const', 'required', 'properties', 'additionalProperties',
  'items', 'minItems', 'maxItems', 'uniqueItems', 'minLength', 'maxLength',
  'pattern', 'minimum', 'maximum', 'format',
]);

function readJson(path) {
  const bytes = fs.readFileSync(path);
  const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  return JSON.parse(text);
}

function typeOf(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (typeof value === 'number') return Number.isInteger(value) ? 'integer' : 'number';
  return typeof value;
}

function matchesType(value, type) {
  const actual = typeOf(value);
  return actual === type || (type === 'number' && actual === 'integer');
}

function realDate(text) {
  const match = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/.exec(text);
  if (!match) return false;
  const [year, month, day] = match.slice(1).map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}

const FORMATS = {
  date: realDate,
};

function same(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function check(schema, value, path, errors) {
  for (const key of Object.keys(schema)) {
    if (!ANNOTATIONS.has(key) && !KEYWORDS.has(key)) {
      throw new Error(`unsupported schema keyword ${key} at ${path}`);
    }
  }
  const fail = (message) => errors.push(`${path}: ${message}`);

  if ('type' in schema) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!types.some((type) => matchesType(value, type))) {
      fail(`type ${typeOf(value)} is not ${types.join(' or ')}`);
      return;
    }
  }
  if ('const' in schema && !same(value, schema.const)) fail(`expected ${JSON.stringify(schema.const)}`);
  if ('enum' in schema && !schema.enum.some((option) => same(value, option))) {
    fail(`${JSON.stringify(value)} is not one of ${JSON.stringify(schema.enum)}`);
  }

  if (typeof value === 'string') {
    if ('minLength' in schema && value.length < schema.minLength) fail(`shorter than ${schema.minLength}`);
    if ('maxLength' in schema && value.length > schema.maxLength) fail(`longer than ${schema.maxLength}`);
    if ('pattern' in schema && !new RegExp(schema.pattern, 'u').test(value)) {
      fail(`${JSON.stringify(value)} does not match ${schema.pattern}`);
    }
    if ('format' in schema) {
      const format = FORMATS[schema.format];
      if (!format) throw new Error(`unsupported format ${schema.format} at ${path}`);
      if (!format(value)) fail(`${JSON.stringify(value)} is not a valid ${schema.format}`);
    }
  }

  if (typeof value === 'number') {
    if ('minimum' in schema && value < schema.minimum) fail(`below ${schema.minimum}`);
    if ('maximum' in schema && value > schema.maximum) fail(`above ${schema.maximum}`);
  }

  if (Array.isArray(value)) {
    if ('minItems' in schema && value.length < schema.minItems) fail(`fewer than ${schema.minItems} items`);
    if ('maxItems' in schema && value.length > schema.maxItems) fail(`more than ${schema.maxItems} items`);
    if (schema.uniqueItems) {
      const seen = new Set(value.map((item) => JSON.stringify(item)));
      if (seen.size !== value.length) fail('items are not unique');
    }
    if ('items' in schema) value.forEach((item, index) => check(schema.items, item, `${path}[${index}]`, errors));
  }

  if (typeOf(value) === 'object') {
    for (const key of schema.required || []) {
      if (!(key in value)) fail(`missing required property ${key}`);
    }
    const properties = schema.properties || {};
    for (const [key, item] of Object.entries(value)) {
      if (key in properties) {
        check(properties[key], item, `${path}.${key}`, errors);
      } else if (schema.additionalProperties === false) {
        fail(`unexpected property ${key}`);
      } else if (typeof schema.additionalProperties === 'object') {
        check(schema.additionalProperties, item, `${path}.${key}`, errors);
      }
    }
  }
}

function main(argv) {
  if (argv.length < 2) {
    process.stderr.write('usage: plan-schema-check.js SCHEMA.json DOCUMENT.json...\n');
    return 2;
  }
  const schema = readJson(argv[0]);
  let failed = 0;
  for (const path of argv.slice(1)) {
    const errors = [];
    try {
      check(schema, readJson(path), '$', errors);
    } catch (error) {
      errors.push(error.message);
    }
    for (const error of errors) process.stderr.write(`FAIL ${path}: ${error}\n`);
    if (errors.length) failed += 1;
  }
  return failed ? 1 : 0;
}

process.exitCode = main(process.argv.slice(2));

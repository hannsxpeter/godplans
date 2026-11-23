#!/usr/bin/env node
'use strict';

// Installs the godplans skill into supported coding-agent skill directories.
// Thin Node wrapper around install.sh so `npx @hxp-tools/godplans` works.

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const INSTALLER = path.join(ROOT, 'install.sh');
const PKG = require('../package.json');

const COLORS = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  green: '\x1b[32m',
  red: '\x1b[31m',
};

function c(color, text) {
  return COLORS[color] + text + COLORS.reset;
}

function usage() {
  console.log(`
${c('bold', 'godplans')} ${c('dim', 'v' + PKG.version)}
Plan everything before anything.

${c('bold', 'Usage')}
  npx @hxp-tools/godplans@latest
  npx @hxp-tools/godplans@latest --project
  npx @hxp-tools/godplans@latest --tools claude,codex
  npx @hxp-tools/godplans@latest --uninstall
  npx @hxp-tools/godplans@latest --help

${c('bold', 'After install')}
  Restart your coding agent, then run:
    /godplans I want to build ...

${c('bold', 'Requirements')}
  A POSIX host with sh. Windows is not supported by the installer.
`);
}

function main(argv) {
  const args = argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    usage();
    return 0;
  }
  if (args.includes('--version') || args.includes('-v')) {
    console.log(PKG.version);
    return 0;
  }

  if (process.platform === 'win32') {
    console.error(c('red', 'godplans installer does not support Windows.'));
    console.error('Clone the repository on a POSIX host and run sh install.sh --copy.');
    return 2;
  }

  if (!fs.existsSync(INSTALLER)) {
    console.error(c('red', 'install.sh missing from package.'));
    return 2;
  }

  console.log(c('cyan', 'godplans') + ' ' + c('dim', 'v' + PKG.version));
  console.log(c('dim', 'Installing the skill...'));
  console.log('');

  const result = spawnSync('sh', [INSTALLER].concat(args), {
    cwd: ROOT,
    stdio: 'inherit',
    env: process.env,
  });

  if (result.error) {
    console.error(c('red', String(result.error.message || result.error)));
    return 1;
  }
  if (result.status === 0) {
    console.log('');
    console.log(c('green', 'Next: restart your agent, then run /godplans with your idea.'));
    console.log(c('dim', 'Docs: ' + (PKG.homepage || 'https://github.com/hannsxpeter/godplans')));
  }
  return result.status == null ? 1 : result.status;
}

process.exitCode = main(process.argv);

#!/usr/bin/env node
// Appends offers to career-ops' inbox through career-ops' own appendToPipeline(),
// so the write takes career-ops' pipeline lock and uses its exact line format.
// Usage: node bridge/append_pipeline.mjs <career-ops-dir> <offers.json>
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { pathToFileURL } from 'url';

const [, , coDir, offersPath] = process.argv;
if (!coDir || !offersPath) {
  console.error('Usage: node append_pipeline.mjs <career-ops-dir> <offers.json>');
  process.exit(2);
}
const offersFile = resolve(offersPath);
process.chdir(resolve(coDir)); // scan.mjs resolves its paths from the checkout
const scan = await import(pathToFileURL(resolve('scan.mjs')).href);
const offers = JSON.parse(readFileSync(offersFile, 'utf-8'));
await scan.appendToPipeline(offers);
console.log(JSON.stringify({ appended: offers.length, pipeline: scan.PIPELINE_PATH }));

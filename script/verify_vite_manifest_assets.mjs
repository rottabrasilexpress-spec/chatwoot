import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDirectory, '..');
const manifestPath = path.join(projectRoot, 'public', 'vite', '.vite', 'manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const referencedAssets = new Set();

for (const entry of Object.values(manifest)) {
  if (typeof entry.file === 'string') referencedAssets.add(entry.file);
  for (const asset of [...(entry.css ?? []), ...(entry.assets ?? [])]) {
    if (typeof asset === 'string') referencedAssets.add(asset);
  }
}

const missingAssets = [...referencedAssets].filter(asset => {
  const assetPath = path.join(projectRoot, 'public', 'vite', asset);
  return !fs.existsSync(assetPath);
});

if (missingAssets.length > 0) {
  console.error(`Missing Vite assets (${missingAssets.length}):`);
  for (const asset of missingAssets) console.error(`- ${asset}`);
  process.exitCode = 1;
} else {
  console.log(`Verified ${referencedAssets.size} Vite assets from ${manifestPath}`);
}

import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const output = resolve(root, 'dist');
const supabaseUrl = process.env.SUPABASE_URL?.trim();
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY?.trim();

if (Boolean(supabaseUrl) !== Boolean(supabaseAnonKey)) {
  throw new Error('Set both SUPABASE_URL and SUPABASE_ANON_KEY, or leave both unset.');
}

let config = await readFile(join(root, 'config.js'), 'utf8');
if (supabaseUrl && supabaseAnonKey) {
  const parsedUrl = new URL(supabaseUrl);
  if (!['https:', 'http:'].includes(parsedUrl.protocol)) {
    throw new Error('SUPABASE_URL must use HTTPS (HTTP is allowed for local development).');
  }
  if (parsedUrl.protocol === 'http:' && !['localhost', '127.0.0.1'].includes(parsedUrl.hostname)) {
    throw new Error('Non-local Supabase URLs must use HTTPS.');
  }
  config = `// Public browser configuration generated at build time.\nwindow.MCTY_CONFIG = ${JSON.stringify({ url: parsedUrl.toString(), anonKey: supabaseAnonKey }, null, 2)};\n`;
}

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await copyFile(join(root, 'index.html'), join(output, 'index.html'));
await writeFile(join(output, 'config.js'), config, 'utf8');
console.log(`Built static site in ${output}`);
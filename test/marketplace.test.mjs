import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import vm from 'node:vm';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const sql = await readFile(new URL('../supabase/schema.sql', import.meta.url), 'utf8');
const lowerSql = sql.toLowerCase();

test('site includes the MCTY admin dashboard and its management views', () => {
  assert.ok(html.includes("const ADMIN_EMAIL='mclintonahairwe9@gmail.com'"));
  for (const tab of ['applications', 'history', 'directory', 'orders', 'audit']) {
    assert.ok(html.includes(`data-tab="${tab}"`), `Missing admin tab: ${tab}`);
  }
  assert.ok(html.includes('mcty_review_application'));
  assert.ok(html.includes('mcty_set_business_active'));
  assert.ok(html.includes('mctyAdminContent'));
});

test('inline browser JavaScript parses', () => {
  const scripts = html.split('<script').slice(1).map((part) => {
    const openEnd = part.indexOf('>');
    const closeStart = part.indexOf('</script>');
    return { attributes: part.slice(0, openEnd), body: part.slice(openEnd + 1, closeStart), closeStart };
  }).filter((script) => script.closeStart !== -1 && !script.attributes.includes('src=') && script.body.trim());
  assert.ok(scripts.length > 0, 'Expected inline application scripts');
  scripts.forEach((script, index) => {
    assert.doesNotThrow(() => new vm.Script(script.body, { filename: `inline-${index + 1}.js` }));
  });
});

test('database policies restrict private operations to the admin email', () => {
  assert.ok(lowerSql.includes('alter table public.business_applications enable row level security'));
  assert.ok(lowerSql.includes('create policy "admin reads applications"'));
  assert.ok(lowerSql.includes('create policy "admin reads order intents"'));
  assert.ok(lowerSql.includes('create policy "admin audit only"'));
  assert.ok(lowerSql.includes("lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com'"));
  assert.ok(lowerSql.includes('mcty_review_application'));
  assert.ok(lowerSql.includes('mcty_set_business_active'));
  assert.ok(lowerSql.includes('administrator access required'));
  const viewStart = lowerSql.indexOf('create view public.public_business_directory as');
  const viewEnd = lowerSql.indexOf(';', viewStart);
  const view = lowerSql.slice(viewStart, viewEnd);
  assert.ok(viewStart >= 0 && viewEnd > viewStart, 'Public directory view is missing');
  for (const privateField of ['owner_email', 'documents', 'review_note']) {
    assert.ok(!view.includes(privateField), `Public directory exposes ${privateField}`);
  }
});
test('Vercel, Render, Netlify, and CI configs target the static build', async () => {
  const vercel = JSON.parse(await readFile(new URL('../vercel.json', import.meta.url), 'utf8'));
  const render = await readFile(new URL('../render.yaml', import.meta.url), 'utf8');
  const netlify = await readFile(new URL('../netlify.toml', import.meta.url), 'utf8');
  const workflow = await readFile(new URL('../.github/workflows/ci.yml', import.meta.url), 'utf8');
  assert.equal(vercel.buildCommand, 'npm run build');
  assert.equal(vercel.outputDirectory, 'dist');
  assert.ok(render.includes('runtime: static'));
  assert.ok(render.includes('staticPublishPath: ./dist'));
  assert.ok(render.includes('autoDeployTrigger: checksPass'));
  assert.ok(netlify.includes('command = "npm run build"'));
  assert.ok(netlify.includes('publish = "dist"'));
  for (const command of ['npm ci', 'npm test', 'npm run build']) assert.ok(workflow.includes(command));
});
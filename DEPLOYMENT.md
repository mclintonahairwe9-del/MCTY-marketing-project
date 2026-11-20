# Deploy the MCTY Marketplace

This is a static HTML site. Supabase provides authentication, the database, and private file storage. Vercel and Render each publish the same `dist/` build and can deploy from the GitHub `main` branch.

## Before deploying

1. Create or select a Supabase project and run `supabase/schema.sql` in its SQL Editor.
2. Enable Email OTP or magic-link sign-in. Invite or create and verify `mclintonahairwe9@gmail.com` in Supabase Auth.
3. In both hosting providers, set the build-time variables:
   - `SUPABASE_URL`: the Supabase Project URL.
   - `SUPABASE_ANON_KEY`: the Supabase publishable key (or legacy anon key).
4. Never use `service_role` as `SUPABASE_ANON_KEY`. This static build publishes the supplied values into `dist/config.js`, where browser users can see them; only the publishable/anon key is intended for that use.

The repository contains placeholders in `config.js`, so the page can build before a Supabase project is configured. The marketplace will not connect until both variables are set in the hosting provider and the site is rebuilt.

## Vercel

1. In Vercel, choose **Add New → Project**, import `mclintonahairwe9-del/MCTY-marketing-project`, and keep the root directory at `.`.
2. The checked-in `vercel.json` sets the build command to `npm run build` and the output directory to `dist`.
3. Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` under **Project Settings → Environment Variables** for Production and Preview. Redeploy after saving them.
4. Keep `main` as the Production Branch. Git pushes create preview deployments, and pushes to `main` update production.
5. To wait for CI before promoting a production deployment, open **Project Settings → Deployment Checks** and select the GitHub Actions **Test and build** check.

## Render

1. In Render, choose **New → Blueprint**, connect the GitHub repository, and apply its `render.yaml`.
2. The Blueprint creates a static site using `npm ci && npm run build`, publishes `dist/`, and asks for `SUPABASE_URL` and `SUPABASE_ANON_KEY` because their values are intentionally not stored in the YAML.
3. Use `main` as the production branch. `autoDeployTrigger: checksPass` waits for the GitHub Actions check before deploying later commits.

Render is hosting the static frontend here; the app's database and authentication remain in Supabase.

## Admin dashboard and Supabase redirects

The app includes an Admin / Owner sign-in. The verified `mclintonahairwe9@gmail.com` account can review pending applications, view review history, manage business visibility, inspect WhatsApp order intents, and view the audit log. The database enforces the admin email through Row Level Security and admin-only database functions.

In **Supabase → Authentication → URL Configuration**, set the Site URL to the canonical hostname you plan to use. Add both provider origins (your `*.vercel.app` and `*.onrender.com` URLs) to Redirect URLs, plus any custom domain. The site requests its sign-in link back to the same origin that the user opened.

After deploying, open **Admin / Owner**, enter `mclintonahairwe9@gmail.com`, and use the email sign-in link. The dashboard will show real records after the schema is installed and visitors have submitted applications or placed WhatsApp order intents.

## CI and local checks

GitHub Actions runs `npm ci`, `npm test`, and `npm run build` on pull requests and pushes to `main`. Render is configured to wait for those checks before its automatic deploy. Vercel can use the same check as a Deployment Check as described above.

Run locally with:

```sh
npm ci
npm test
npm run build
```
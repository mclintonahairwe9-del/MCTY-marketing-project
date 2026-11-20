# MCTY Marketplace — production launch checklist

**Launch strategy:** C — Uganda first, designed to expand across East Africa.
**Admin email:** `mclintonahairwe9@gmail.com`
**Hosting:** Vercel and Render static sites (Netlify config is also retained)
**Ordering/payment:** WhatsApp handoff; seller and customer coordinate payment directly.
**Custom domain:** deferred until selected.

## 1. Create / configure Supabase

1. Sign in at https://supabase.com/dashboard and create a project named `mcty-marketplace` (or use your existing project).
2. Open **SQL Editor** and run the complete `supabase/schema.sql` file. It includes migration steps for the earlier MCTY starter schema. Run it once, and inspect the SQL Editor result for errors before continuing.
3. Open **Authentication → Providers → Email** and enable email OTP / magic-link sign-in.
4. Under **Authentication → URL Configuration**, set the Site URL to your chosen canonical hostname. Add both the Vercel and Render origins to Redirect URLs, plus your eventual custom domain. The app returns sign-in links to the same origin where the user opened it.
5. Under **Authentication → Users**, invite or create `mclintonahairwe9@gmail.com`, then verify the email. Administrator permissions are checked by database policies against this exact verified email.
6. Under **Project Settings → API**, copy the Project URL and the public publishable key (or legacy anon key). Put those two public values either in `config.js` for local hosting, or in the `SUPABASE_URL` and `SUPABASE_ANON_KEY` build-time environment variables on Vercel and Render. The build writes them into the public `config.js` file:

```js
window.MCTY_CONFIG = {
  url: 'https://YOUR_PROJECT_REF.supabase.co',
  anonKey: 'YOUR_PUBLIC_PUBLISHABLE_OR_ANON_KEY'
};
```

Do not use the `service_role` key. It bypasses Row Level Security and must never be shipped to a browser.

## 2. Private application and document review

- The registration form accepts business identity/contact details, category, location, private registration/licence number, product/menu list, website/social links and optional supporting documents.
- Supporting files are limited to five per application, 8 MB each, PDF/JPEG/PNG/WebP. They are placed in the private `mcty-private-applications` bucket.
- Approved owners can upload a public business cover image (JPG/PNG/WebP, 5 MB maximum) to the separate `mcty-business-media` bucket.
- Anonymous visitors can submit an application but cannot read the application table or private files.
- Sign in at **Admin / Owner** with the administrator email. The admin area contains Pending applications, Review history, Businesses, Order activity and Audit log.
- Open private supporting documents from the admin review screen. Links expire after three minutes.
- Approving an application creates its public business listing in one database transaction. Rejecting stores the private review note and does not publish the listing.
- Suspension removes a listing from public discovery without deleting its record.

## 3. Business owner access

1. After approval, the business owner opens **Admin / Owner** and requests an email sign-in link using the same email address submitted on the application.
2. Once authenticated, the owner can edit the public description, order WhatsApp number, advert, website/social links and product/service list, and upload a shop cover image.
3. The owner cannot edit their email, approval status or public visibility.

## 4. Deploy on Vercel and Render

1. Connect this GitHub repository to Vercel and import it with the root directory set to `.`. The checked-in `vercel.json` sets `npm run build` and publishes `dist/`.
2. Connect the same GitHub repository to Render using **New → Blueprint**. The checked-in `render.yaml` creates a static site, publishes `dist/`, and waits for GitHub CI checks before later deploys.
3. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in both providers before the first production build. Use the public publishable/anon key, never the `service_role` key.
4. Vercel deploys previews for branch pushes and production from `main`. In Vercel Deployment Checks, select the GitHub Actions **Test and build** check if production should wait for CI. Render's Blueprint already uses `autoDeployTrigger: checksPass`.
5. Add the Vercel and Render hostnames to Supabase Auth Redirect URLs, then verify both deployment URLs load the app.
6. Netlify remains supported by `netlify.toml` if you prefer to use it later.
## 5. Mandatory launch tests

- Submit an application with one private test PDF or image.
- Confirm an anonymous browser cannot read `business_applications`, `businesses` or the private Storage bucket.
- Confirm only the verified administrator can see the application and open its private documents.
- Approve a test application and confirm it appears in the public directory without exposing the owner email.
- Reject another test application and confirm it never appears publicly.
- Suspend and restore an approved listing.
- Sign in as the approved owner and update the profile and catalogue.
- Place a WhatsApp test order and confirm the correct seller chat opens. Check the admin order-intent record.
- Test Android and desktop layouts, form validation and error states.

## 6. Before advertising registration widely

- Enable CAPTCHA / bot protection and server-side rate limiting for public applications and uploads. The SQL limits file types and sizes, but does not itself provide an IP-based submission throttle. This package has file size/type limits and database RLS, but a public anonymous form still needs anti-abuse controls before a high-traffic launch.
- Publish a privacy notice and decide a retention/deletion schedule for rejected applications and supporting documents.
- Confirm every business phone and WhatsApp number with its owner.
- Configure a custom domain and email deliverability after the launch URL is stable. Enable administrator MFA in Supabase Auth if available.

## 7. Revenue model and payments

MCTY can start with free basic listings and earn from optional featured placement, sponsored adverts, premium business tools and marketing services. Add seller commissions only when completed orders can be reliably confirmed. WhatsApp handoff does not prove payment; this release does not collect mobile money, card payments or subscription fees.

## 8. East Africa expansion

The data model stores `country_code` and `currency_code`; the registration form includes Uganda, Kenya, Tanzania, Rwanda, Burundi and South Sudan. Launch and validate Uganda first, then configure country-specific phone validation, currency display, tax/legal notices, support and localisation before opening each additional market.

## Support contact

MCTY support WhatsApp number in international format: `+256 776 565 420`.

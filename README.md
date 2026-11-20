# MCTY Marketplace — full marketplace release

A mobile-first marketplace built from the supplied MCTY design. The black-and-gold identity, motion, category discovery, business profile presentation and WhatsApp order journey are retained and extended rather than replaced.

## What this release contains

- Marketplace discovery across 15 business categories, search and town filtering.
- Uganda-first launch with country and currency fields for Uganda, Kenya, Tanzania, Rwanda, Burundi and South Sudan. The data model is ready for more East African countries.
- Public directory is populated only from the approved-business view. Demo/sample listings have been removed from the live dataset.
- Business applications are stored in a private review inbox. Anonymous visitors can submit; they cannot read applications or private review notes.
- Optional supporting documents (PDF/JPG/PNG/WebP, up to five files, 8 MB each) are stored in a private Supabase Storage bucket. Only the administrator can open them, using short-lived signed links.
- Approved business owners can upload a public shop cover image (JPG/PNG/WebP, up to 5 MB) and maintain website/social links.
- Admin sign-in by email OTP for `mclintonahairwe9@gmail.com`.
- Private pending queue, review history, approve/reject, business suspension/restoration, private review notes and audit trail.
- Approval atomically creates the public listing. A rejected or pending application never appears in the public directory.
- Approved owners can sign in using the email on the approved application and update their description, WhatsApp order number, advert and catalogue.
- WhatsApp order handoff and basic order-intent analytics. This records an order attempt, not a completed sale or payment.
- Business growth section describing featured placement, premium tools and marketing services as future revenue options.
- GitHub Actions CI and static deployment configurations for Vercel, Render, and Netlify.

## Production setup

Read `UPGRADE_NOTES.md` for the changes from the supplied source, then follow `PRODUCTION_SETUP.md` in order. The package is deploy-ready after the Supabase project is configured, the SQL is run, `config.js` is filled with the public project URL and publishable key, and the admin email is verified in Supabase Auth.

## Security boundaries

- `config.js` contains only public browser values. Never place a database password, Supabase `service_role` key, Netlify token or other secret in HTML or JavaScript.
- Applications and supporting documents are private. The public directory view intentionally omits owner email and application data.
- Admin privileges are enforced by PostgreSQL Row Level Security and security-definer review functions, not by hiding an admin button in the browser.
- Owners cannot approve themselves, change their owner email or change listing visibility.
- WhatsApp is an order handoff. No money is collected or verified by MCTY in this release.

## Before broad public promotion

Configure abuse protection / CAPTCHA and a server-side rate limit for public applications and document uploads. Review the privacy notice and retention process, test the admin workflow on a second device, and verify seller contact details. These require account-level provider settings and cannot be truthfully marked complete from a source-code package alone.


## Deploying

See [DEPLOYMENT.md](DEPLOYMENT.md) for Vercel, Render, Supabase, and CI setup steps.

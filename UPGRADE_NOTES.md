# MCTY Marketplace — release notes

## Direction selected

- **Platform:** full marketplace
- **Launch footprint:** Uganda first, East Africa-ready data model
- **Business onboarding:** private administrator approval
- **Customer ordering:** WhatsApp handoff
- **Payments:** no integrated gateway in this release; seller/customer settle directly
- **Visual approach:** retain the supplied MCTY black-and-gold look and improve its product workflows rather than replacing the brand

## What changed from the supplied HTML

1. Removed hard-coded demo businesses and sample adverts from the live directory. Only approved database listings are displayed.
2. Expanded categories beyond the initial six to include tourism, transport, health, professional services, real estate, events, agriculture, technology and home services.
3. Search now includes business details and product/service names.
4. Added country/currency fields for Uganda, Kenya, Tanzania, Rwanda, Burundi and South Sudan.
5. Replaced WhatsApp-only application submission with a shared application record in Supabase.
6. Added private supporting-document uploads and administrator-only, expiring document links.
7. Added private admin pending queue, review history, audit log, approval/rejection and suspend/restore controls.
8. Approval now creates the public listing through a database function guarded by the administrator's verified email.
9. Added verified-email business owner workspace for profile, catalogue, website/social links and public cover image management.
10. Added dynamic featured adverts from approved business profiles.
11. Added order-intent analytics for WhatsApp handoffs without falsely representing them as confirmed sales or payments.
12. Added public-facing business benefits, revenue opportunities and privacy/trust explanations.
13. Added Netlify security headers and deployment configuration.

## Important boundary

The source package cannot create a Supabase project, verify the administrator's inbox, set account-level CAPTCHA/rate limiting, or deploy to a Netlify account without the account owner's setup/authorization. Complete `PRODUCTION_SETUP.md` before publishing as a live service.

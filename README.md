# Wrap My Cover - Commerce Site

Rails 8 app providing the public site, accounts, and payments for Wrap My Cover
(architecture A: this app fronts the Python editor engine).

Wrap My Cover is built by [Lee Powell](https://leepowell.com), an author, founder
and software engineer in Melbourne. Lee built document software used by writers
worldwide, including Scrivener and Scapple for Windows, and runs
[Lumen & Lever](https://lumenandlever.com), an AI engineering studio for
traceable document systems and production workflows.

The public site carries that identity through its founder page, case studies,
sitemap, Open Graph tags and schema.org JSON-LD.

## Stack

- Rails 8.1 / Ruby 3.3, PostgreSQL, Tailwind CSS v4 (importmap, no Node build)
- Devise (confirmable, lockable, timeoutable, trackable, paranoid mode)
- Stripe hosted Checkout + Billing Portal + signed webhooks (no card data touches this app)
- rack-attack throttles/bans, invisible_captcha honeypot+timing+spinner, strict CSP

## Local development

```bash
cd site
bundle install
bin/rails db:prepare
bin/rails tailwindcss:build   # or bin/dev for watch mode
bin/rails server
```

Copy `.env.example` and export real Stripe **test-mode** values. Create two
Prices in the Stripe dashboard (one-time $14.99, recurring $99/yr) and set
`STRIPE_PRICE_BOOK` / `STRIPE_PRICE_PRO`. For webhooks locally:

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

## Tests & security gates

```bash
bundle exec rspec         # 51 examples: auth, session caps, billing, webhooks, rate limits
bundle exec brakeman -q   # static security analysis (clean)
```

Notes for spec authors: rack-attack is disabled by default in specs — tag an
example group `:rack_attack` to enable it with a fresh counter store.
Invisible-captcha timestamp/spinner checks are test-disabled; the honeypot is
always active (post it empty like a browser would).

## Security posture (summary)

Hardened against an adversarial review (see below). Key controls:

- Sessions: no remember-me — an active login is required each session so that
  server-side revocation and the device cap are always binding. 30-min idle
  timeout; max 3 concurrent devices (oldest revoked); revocable from the
  account page.
- Sign-in: 5 failed attempts locks the account (email/time unlock); paranoid
  responses never reveal whether an account exists — including on the
  registration form (an existing email gets the same "check your email"
  response and the real owner is notified by mail).
- Passwords: 12+ chars, cannot contain the email local-part.
- Bots: honeypot + minimum-submit-time + session-bound form token on
  signup/password forms.
- Rate limits: per-IP global, per-IP and per-email login, signup floods,
  password-reset and confirmation floods (per IP *and* per destination email),
  checkout floods. Throttle keys normalise the path (format suffix and trailing
  slash stripped) so `/users/sign_in.json` cannot bypass them. Counter store is
  Redis when `REDIS_URL` is set, else a fast in-process store (never the DB).
  Scanner paths ban after repeated probes (not one strike, to spare shared IPs).
  429 + Retry-After.
- Payments: Stripe Checkout hosted pages; webhook signature verification with a
  secret that fails closed in production (no placeholder fallback); event
  idempotency table. Entitlement is granted only for genuinely-paid sessions
  (`payment_status == "paid"`, plus `async_payment_succeeded` for delayed
  methods); subscriptions activate only when the subscription webhook reports a
  real active status; refunds and disputes revoke access
  (`charge.refunded` / `charge.dispute.created`).
- Headers: strict CSP (no inline scripts, per-request random nonce,
  frame-ancestors 'none'), SSL forced in production.

## Adversarial security review

A multi-agent review (4 attack surfaces, each finding adversarially verified)
surfaced 12 candidate issues; 10 were confirmed and fixed, 2 refuted. Highlights
fixed: remember-me defeating session revocation, checkout granting access before
payment settled, subscriptions activating before the first invoice paid,
webhook-secret placeholder fallback, and a rate-limit bypass via `.json` path
suffixes. Every fix has a regression spec (see `spec/requests/webhooks_spec.rb`,
`registrations_spec.rb`, `sessions_spec.rb`, `rack_attack_spec.rb`).

## Deploy (Heroku)

```bash
heroku create kdp-cover-builder
heroku addons:create heroku-postgresql:essential-0
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key) \
  STRIPE_SECRET_KEY=... STRIPE_WEBHOOK_SECRET=... \
  STRIPE_PRICE_BOOK=... STRIPE_PRICE_PRO=... \
  APP_HOST=yourdomain.com MAILER_SENDER=no-reply@yourdomain.com
git push heroku main
```

`Procfile` runs `db:prepare` in the release phase. Add the production webhook
endpoint (`https://yourdomain.com/webhooks/stripe`) in the Stripe dashboard,
subscribing to `checkout.session.completed` and `customer.subscription.*`.
Configure an SMTP provider (e.g. Postmark) for Devise mail before launch.
Rack-attack counters use Rails.cache (Solid Cache): fine at launch scale;
point at Redis when running multiple dynos.

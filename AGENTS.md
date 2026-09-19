# Rocketbox

Rocketbox handles marketing for small businesses while owners keep doing their craft.

## Product

**Pitch:** We handle marketing for you while you work.

**Loop (once live):**
1. One-time setup — crawl the business website and social presence
2. Owner sends media during the day (Telegram today; more connectors later)
3. Fully automated Instagram publishing — Reels, Stories, and feed posts
4. Owner can delete anything they dislike after it goes live (typically after work)

**Not the homepage story:** Setup/run mechanics stay off the public marketing surface. Ads target specific verticals (barbershops, salons, etc.); the site speaks to “your business.”

**Current go-to-market:** Closed beta. Public CTA is join the waitlist at `/try` ([waitlists](/app/controllers/waitlists_controller.rb)). Visitor leaves business link (site or Instagram), email, and phone. We respond with a personalized pack (WhatsApp). If they like it, full onboarding follows (coming soon). No public pricing yet.

**Proof / examples:** Use-case pages under `/use-cases/:slug` ([registry](/app/controllers/use_cases_controller.rb)), with real barbershop demos reused on the home page.

# Documentation Index

### [STRIPE.md](./docs/STRIPE.md)
Payments and billing via Stripe.

### [TELEGRAM.md](./docs/TELEGRAM.md)
Telegram bot: inbound media, webhooks, outbound messaging.

### [LOGIN.md](./docs/LOGIN.md)
Authentication and session login.

### [DEPLOY.md](./docs/DEPLOY.md)
How the app is deployed and operated in production.

# Stripe

Recurring subscriptions via Stripe Checkout. Local `Subscription` rows mirror Stripe state; `active` unlocks paid book chapters.

## Credentials

Encrypted Rails credentials (`bin/rails credentials:edit`), read by [`config/initializers/stripe.rb`](/config/initializers/stripe.rb):

- `stripe.secret_key` — API key (`Stripe.api_key`)
- `stripe.price_id` — recurring Price used for Checkout
- `stripe.webhook_secret` — signing secret for the Dashboard webhook endpoint

In development, [`StripeCredentials.webhook_secret`](/config/initializers/stripe.rb) prefers `STRIPE_WEBHOOK_SECRET` from the environment (Stripe CLI) over credentials.

Gem: `stripe` in [`Gemfile`](/Gemfile).

## Local webhooks

[`Procfile.dev`](/Procfile.dev) runs `stripe listen` forwarding to `http://127.0.0.1:3000/stripe/webhook`. Copy the CLI signing secret into `.env` as `STRIPE_WEBHOOK_SECRET`. The Rails server is pinned to port 3000 so forwarding stays stable.

## Checkout and billing portal

Signed-in users start Checkout or open the Customer Portal from [`/account/subscription`](/app/controllers/accounts/subscriptions_controller.rb) ([`app/controllers/accounts_controller.rb`](/app/controllers/accounts_controller.rb)). Same Checkout button appears for signed-in non-subscribers via [`app/views/shared/_subscription_action_buttons.html.erb`](/app/views/shared/_subscription_action_buttons.html.erb).

Routes: `POST /account/checkout`, `POST /account/portal` ([`config/routes.rb`](/config/routes.rb)).

Checkout runs in `subscription` mode with the configured price, sets `client_reference_id` / metadata `user_id` for linking, reuses `stripe_customer_id` when present (otherwise pre-fills email), and returns to `/account/subscription`. Portal requires an existing Stripe customer id.

Guests use a separate magic-link subscribe flow ([`app/controllers/subscriptions_controller.rb`](/app/controllers/subscriptions_controller.rb)) to create an account; Stripe Checkout only runs after sign-in.

## Data model

[`app/models/subscription.rb`](/app/models/subscription.rb) — one row per user (created on user signup). Stripe-related fields: `stripe_customer_id`, `stripe_subscription_id`, `status`, `current_period_end`, `active`.

Access is granted when Stripe status is `active` or `trialing` (`Subscription.stripe_status_grants_access?`). Paid chapters check `subscription.active?` in [`app/controllers/books/books_controller.rb`](/app/controllers/books/books_controller.rb).

Admins can patch their own status on the account page for testing (does not call Stripe). Avo resource: [`app/avo/resources/subscription.rb`](/app/avo/resources/subscription.rb).

## Webhooks

`POST /stripe/webhook` → [`app/controllers/stripe_webhooks_controller.rb`](/app/controllers/stripe_webhooks_controller.rb): verifies the Stripe signature, then enqueues [`app/jobs/process_stripe_webhook_job.rb`](/app/jobs/process_stripe_webhook_job.rb).

Handled events:

- `checkout.session.completed` (subscription mode) — stores customer id from `client_reference_id`, then syncs the Stripe subscription
- `customer.subscription.updated` / `customer.subscription.deleted` — re-fetch and sync

Sync logic: [`app/services/stripe_subscription_sync.rb`](/app/services/stripe_subscription_sync.rb). Resolves the user via subscription metadata `user_id`, else by existing `stripe_customer_id`.

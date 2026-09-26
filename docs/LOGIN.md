# Login

Passwordless email OTP + magic-link sign-in with cookie-backed sessions.

## Session model

[`app/models/user.rb`](/app/models/user.rb) — unique normalized email, `verified` flag, `role` (`user` / `admin`), optional `name` / `business_name` / `whatsapp_phone`. Creates a default inactive subscription on signup. OTP/magic-link success uses `User.find_or_create_from_login!` (creates if new; marks `verified: true`).

[`app/models/session.rb`](/app/models/session.rb) — one row per signed-in device; stores `user_agent` and `ip_address` from [`app/models/current.rb`](/app/models/current.rb).

Auth cookie: signed permanent httponly `session_token` holding the session id. Set on sign-in / sign-up; read on every request in [`app/controllers/application_controller.rb`](/app/controllers/application_controller.rb) (`resume_session` → `Current.session`).

## Gatekeeping

Almost everything requires a session (`before_action :authenticate`). Public exceptions: home GET `/`, document show, plus controllers that `skip_before_action :authenticate` (sessions OTP/magic, signups, email verification show, Stripe/Telegram webhooks, guest subscribe flow).

Unauthenticated users are redirected to `/sign_in`.

## Sign in / out

Routes in [`config/routes.rb`](/config/routes.rb):

- `GET/POST /sign_in` — email form; issues OTP + magic link email
- `GET/POST /sign_in/otp` — enter code
- `GET /sign_in/magic?sid=` — one-click login from email
- `resources :sessions` (index + destroy)
- development-only `POST /dev_sign_in`

[`app/services/login_challenge.rb`](/app/services/login_challenge.rb) — 6-digit OTP (BCrypt digest in `Rails.cache`, 15 min), magic link via `MessageVerifier`, 60s resend throttle, 5 attempt cap. Always shows “check your email” (no enumeration).

[`app/controllers/sessions_controller.rb`](/app/controllers/sessions_controller.rb) — OTP/magic path creates or finds user then mints session + cookie. Logout destroys a session owned by `Current.user`. Dev shortcut signs in a fixed local user.

Mail: [`UserMailer#login_otp`](/app/mailers/user_mailer.rb) (Postmark `login_otp`) with code + magic URL.

UI: [`app/views/sessions/new.html.erb`](/app/views/sessions/new.html.erb), [`otp`](/app/views/sessions/otp.html.erb), device list [`app/views/sessions/index.html.erb`](/app/views/sessions/index.html.erb). Header: Sign in / Get started (marketing) or Go to Dashboard (signed in) ([`app/views/shared/_page_header.html.erb`](/app/views/shared/_page_header.html.erb)).

## Sign up

Multi-step wizard ([`SignupsController`](/app/controllers/signups_controller.rb), layout [`signup`](/app/views/layouts/signup.html.erb) with hero wave):

1. Name → 2. Business name → 3. Email → 4. Email OTP (Postmark `login_otp`; code also shown on page in development) → creates user + session → 5. Phone (skippable) → 6. Phone OTP stub (`000000` shown; SMS not implemented) → `/app`.

Draft for steps 1–3 lives in `session[:signup]`. Existing email redirects to sign-in. Phone stores on `whatsapp_phone`.

Routes: `GET /sign_up` plus `/sign_up/name`, `/business`, `/email`, `/email_code`, `/phone`, `/phone_code`, and `POST /sign_up/phone/skip`.

## Email verification

Rails `generates_token_for :email_verification` (2 days, bound to email). Sent via [`UserMailer`](/app/mailers/user_mailer.rb) (Postmark `email_verification`) when changing email.

[`app/controllers/identity/email_verifications_controller.rb`](/app/controllers/identity/email_verifications_controller.rb) — link with `sid` marks `verified: true`; signed-in users can resend. Changing email ([`app/controllers/identity/emails_controller.rb`](/app/controllers/identity/emails_controller.rb)) clears verified and re-sends.

OTP/magic-link login and signup email OTP already set `verified: true`.

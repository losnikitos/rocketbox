# Login

Email-first OTP + magic-link sign-in with cookie-backed sessions. Password sign-in remains a secondary path. Subscribe “magic links” only pre-fill sign-up — see [STRIPE.md](./STRIPE.md).

## Session model

[`app/models/user.rb`](/app/models/user.rb) — `has_secure_password`, unique normalized email, min 12-char password (when set), `verified` flag, `role` (`user` / `admin`). Creates a default inactive subscription on signup. OTP/magic-link success uses `User.find_or_create_from_login!` (creates with a random password if new; marks `verified: true`).

[`app/models/session.rb`](/app/models/session.rb) — one row per signed-in device; stores `user_agent` and `ip_address` from [`app/models/current.rb`](/app/models/current.rb).

Auth cookie: signed permanent httponly `session_token` holding the session id. Set on sign-in / sign-up; read on every request in [`app/controllers/application_controller.rb`](/app/controllers/application_controller.rb) (`resume_session` → `Current.session`). Changing password invalidates other sessions.

## Gatekeeping

Almost everything requires a session (`before_action :authenticate`). Public exceptions: home GET `/`, document show, plus controllers that `skip_before_action :authenticate` (sessions OTP/password/magic, registrations, password reset, email verification show, Stripe/Telegram webhooks, books index/preview, guest subscribe/preview flows).

Unauthenticated users are redirected to `/sign_in`.

## Sign in / out

Routes in [`config/routes.rb`](/config/routes.rb):

- `GET/POST /sign_in` — email form; issues OTP + magic link email
- `GET/POST /sign_in/otp` — enter code
- `GET /sign_in/magic?sid=` — one-click login from email
- `GET/POST /sign_in/password` — secondary password auth
- `resources :sessions` (index + destroy)
- development-only `POST /dev_sign_in`

[`app/services/login_challenge.rb`](/app/services/login_challenge.rb) — 6-digit OTP (BCrypt digest in `Rails.cache`, 15 min), magic link via `MessageVerifier`, 60s resend throttle, 5 attempt cap. Always shows “check your email” (no enumeration).

[`app/controllers/sessions_controller.rb`](/app/controllers/sessions_controller.rb) — OTP/magic path creates or finds user then mints session + cookie; password path uses `User.authenticate_by`. Logout destroys a session owned by `Current.user`. Dev shortcut signs in a fixed local user.

Mail: [`UserMailer#login_otp`](/app/mailers/user_mailer.rb) (Postmark `login_otp`) with code + magic URL.

UI: [`app/views/sessions/new.html.erb`](/app/views/sessions/new.html.erb), [`otp`](/app/views/sessions/otp.html.erb), [`password`](/app/views/sessions/password.html.erb), device list [`app/views/sessions/index.html.erb`](/app/views/sessions/index.html.erb). Header links Sign in / My account ([`app/views/shared/_page_header.html.erb`](/app/views/shared/_page_header.html.erb)). Account page logout ([`app/views/accounts/show.html.erb`](/app/views/accounts/show.html.erb), [`app/controllers/accounts_controller.rb`](/app/controllers/accounts_controller.rb)). Integrations ([`/account/integrations`](/app/controllers/accounts/integrations_controller.rb)) lets the signed-in user set Instagram user id / access token and Telegram user id on their `User` row.

## Sign up

`GET/POST /sign_up` → [`app/controllers/registrations_controller.rb`](/app/controllers/registrations_controller.rb). Creates user, session cookie, and queues email verification. View: [`app/views/registrations/new.html.erb`](/app/views/registrations/new.html.erb).

OTP sign-in also creates an account on first successful verify (no separate sign-up required).

## Email verification

Rails `generates_token_for :email_verification` (2 days, bound to email). Sent via [`app/mailers/user_mailer.rb`](/app/mailers/user_mailer.rb) (Postmark `email_verification`).

[`app/controllers/identity/email_verifications_controller.rb`](/app/controllers/identity/email_verifications_controller.rb) — link with `sid` marks `verified: true`; signed-in users can resend. Changing email ([`app/controllers/identity/emails_controller.rb`](/app/controllers/identity/emails_controller.rb)) clears verified and re-sends.

OTP/magic-link login already sets `verified: true`.

## Passwords

Change while signed in: `resource :password` → [`app/controllers/passwords_controller.rb`](/app/controllers/passwords_controller.rb) (requires `password_challenge`).

Forgot password: `identity/password_reset` → [`app/controllers/identity/password_resets_controller.rb`](/app/controllers/identity/password_resets_controller.rb). Only verified emails get a reset mail; token expires in 20 minutes (`generates_token_for :password_reset`). Views under [`app/views/identity/password_resets/`](/app/views/identity/password_resets/).

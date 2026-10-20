# App review request for Rocketbox

- **App ID:** 1836367217546891
- **Submitted:** 2026-10-03
- **Downloaded:** 2026-10-20
- **Source PDF:** [original-submission.pdf](./original-submission.pdf)

---

## Permission usage

### `instagram_business_basic`

**Tell us how you're using this permission or feature**

Business owners connect their Instagram professional account to Rocketbox through Instagram Login. We read the account's user ID, username, profile picture and basic profile details. We need the ID to publish to the right account, and we show the username and picture on the owner's dashboard so they can confirm which account is connected. We don't share this data with anyone.

**Video walkthrough**

[01-instagram_business_basic.mp4](./01-instagram_business_basic.mp4) (~19s)

**Allowed usage acknowledgment**

The `instagram_business_basic` allows your app to read an Instagram Business account profile's info and media. The allowed usage for this permission is to get basic metadata of an Instagram Business account profile, for example username and ID. You may also use this permission to request analytics insights to improve your app and for marketing or advertising purposes, through the use of aggregated and de-identified or anonymized information (provided such data cannot be re-identified).

If approved, I agree that any data I receive through `instagram_business_basic` will be used in accordance with the allowed usage.

---

### `whatsapp_business_messaging`

**Tell us how you're using this permission or feature**

Owners interact with Rocketbox by chatting with our WhatsApp Business number. We receive their messages and media, save the media to their private library, and reply in the same chat with onboarding questions, sign-in links and confirmations that we received their media. All messages are one-to-one replies in a chat the owner started, never marketing or bulk messages.

**Video walkthrough**

[02-whatsapp_business_messaging.mp4](./02-whatsapp_business_messaging.mp4) (~74s)

**Allowed usage acknowledgment**

The `whatsapp_business_messaging` permission allows an app to send WhatsApp messages to a specific phone number, upload and retrieve media from messages, manage and get WhatsApp business profile information, and to register those phone numbers with Meta. The allowed usage for this permission is to create messaging experiences initiated by a customer or a business. You may also use this permission to request analytics insights to improve your app and for marketing or advertising purposes, through the use of aggregated and de-identified or anonymized information (provided such data cannot be re-identified).

If approved, I agree that any data I receive through `whatsapp_business_messaging` will be used in accordance with the allowed usage.

---

### `instagram_business_content_publish`

**Tell us how you're using this permission or feature**

Owners send photos and videos of their work to Rocketbox over WhatsApp. We turn that media into Instagram posts with captions and publish them to the owner's connected account, so their Instagram stays active without them posting. Every post also appears in the owner's dashboard, where they can remove it.

**Video walkthrough**

[03-instagram_business_content_publish.mp4](./03-instagram_business_content_publish.mp4) (~64s)

**Allowed usage acknowledgment**

The `instagram_business_content_publish` permission allows an app to create organic feed photo and video posts on behalf of a business user. The allowed usage of this permission is to allow an app to manage the organic content creation process for Instagram (for example, post photos and videos) on behalf of an Instagram business account. You may also use this permission to request analytics insights to improve your app and for marketing or advertising purposes, through the use of aggregated and de-identified or anonymized information (provided such data cannot be re-identified).

If approved, I agree that any data I receive through `instagram_business_content_publish` will be used in accordance with the allowed usage.

---

### `public_profile`

**Tell us how you're using this permission or feature**

*(no answer provided in original submission)*

**Allowed usage acknowledgment**

The `public_profile` permission allows apps to read the Default Public Profile Fields on a User node. The allowed usage for this permission is to authenticate app users and provide them with a personalized in-app experience. This permission is automatically granted to all apps. You may also use this permission to request analytics insights to improve your app and for marketing or advertising purposes, through the use of aggregated and de-identified or anonymized information (provided such data cannot be re-identified).

If approved, I agree that any data I receive through `public_profile` will be used in accordance with the allowed usage.

---

### `whatsapp_business_management`

**Tell us how you're using this permission or feature**

We use this to manage Rocketbox's own WhatsApp Business Account: webhook subscriptions, callback URLs and phone number settings. We don't access our customers' WhatsApp Business Accounts.

**Video walkthrough**

[04-whatsapp_business_management.mp4](./04-whatsapp_business_management.mp4) (~43s)

**Allowed usage acknowledgment**

The `whatsapp_business_management` permission allows your app to read and/or manage WhatsApp business assets you own or have been granted access to by other businesses through this permission. These business assets include WhatsApp business accounts, phone numbers, message templates, QR codes and their associated messages, and webhook subscriptions. The allowed usage for this permission is to manage WhatsApp business assets and display WhatsApp Business Account analytics in your customer portal. You may also use this permission to request analytics insights to improve your app and for marketing or advertising purposes, through the use of aggregated and de-identified or anonymized information (provided such data cannot be re-identified).

If approved, I agree that any data I receive through `whatsapp_business_management` will be used in accordance with the allowed usage.

---

## Data handling

### Processors

**Do you have data processors or service providers that will have access to Platform Data from Meta?**

Yes

**List of processors**

| Processor | Service category | Countries |
|---|---|---|
| Firecrawl | IT solutions and services, including cloud storage and processing | United States of America |
| Postmark | IT solutions and services, including cloud storage and processing | United States of America |
| xAI | IT solutions and services, including cloud storage and processing | United States of America |
| Amazon Web Services | IT solutions and services, including cloud storage and processing | Ireland; United States of America |
| OVHcloud | IT solutions and services, including cloud storage and processing | Germany; France |

### Responsible party

- **Legal entity:** TADAAA! LTD
- **Country:** United Kingdom

### Public authority requests

- **Have you provided personal data to public authorities in response to national security requests in the past 12 months?** No
- **Policies/processes regarding such requests:** None of the above

---

## Web reviewer instructions

Provide instructions for accessing the app so we may complete our review. Explain how to navigate to the app, and provide instructions for testing.

**TL;DR**

1. Open https://rocketbox.plus/sign_in
2. Email: `review@meta.com`, password: `review_2026`
3. Connect Instagram and WhatsApp
4. Send some media via WhatsApp
5. Turn into AI video in Library
6. Post it to Instagram in Posts

**Full instructions**

Rocketbox (https://rocketbox.plus) runs Instagram marketing for small businesses: owners send photos over WhatsApp, and we publish them to their Instagram professional account. We don't use Facebook Login. Instagram is connected through Instagram Login (`instagram_business_basic`, `instagram_business_content_publish`).

1. Go to https://rocketbox.plus/sign_in, enter `review@meta.com`, click "Login with password instead" and enter `review_2026`.
2. **WhatsApp:** open https://rocketbox.plus/app/whatsapp, then scan the QR code or tap the link and send the prefilled message. The page then shows your number as connected. Send a few photos to the chat: the bot reacts with 👍 and they appear under Library > Uploads (`whatsapp_business_messaging`).
3. **Instagram:** open https://rocketbox.plus/app/instagram/profile, click "Connect Instagram" and sign in with an Instagram professional account. The page then shows the username, profile picture, bio and follower counts (`instagram_business_basic`).
4. **Publishing:** in Library > Uploads, select photos, click "Create post", choose a style and submit. When the post shows "ready" (a few minutes), click "Publish". The Reel appears on the connected Instagram account (`instagram_business_content_publish`).

**Alternative sign-up flow** (how real customers join, with no email): open https://rocketbox.plus/sign_up and send `START` to our WhatsApp number. The bot guides onboarding and sends a "Connect Instagram" button that signs you in and opens Instagram Login.

### Is Facebook Login integrated on this platform?

No

### Test credentials (optional)

Email: `review@meta.com`. Click "Login with password instead", password: `review_2026`. No payment required.

### Gift codes / geo restrictions

*(not provided)*

### Supporting documentation

[05-full-flow.mov](./05-full-flow.mov) (~3m 23s) — screen recording of the full access / login / API usage flow.

---

## Attachments checklist

| File | Role | Duration | Size |
|---|---|---|---|
| [01-instagram_business_basic.mp4](./01-instagram_business_basic.mp4) | Permission walkthrough | ~19s | 261 KB |
| [02-whatsapp_business_messaging.mp4](./02-whatsapp_business_messaging.mp4) | Permission walkthrough | ~74s | 1.4 MB |
| [03-instagram_business_content_publish.mp4](./03-instagram_business_content_publish.mp4) | Permission walkthrough | ~64s | 972 KB |
| [04-whatsapp_business_management.mp4](./04-whatsapp_business_management.mp4) | Permission walkthrough | ~43s | 590 KB |
| [05-full-flow.mov](./05-full-flow.mov) | Supporting documentation | ~3m 23s | 79 MB |
| [original-submission.pdf](./original-submission.pdf) | Source export from Meta | — | 1.0 MB |

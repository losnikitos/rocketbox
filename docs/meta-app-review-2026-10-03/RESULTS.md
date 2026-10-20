# Meta App Review results

Observed in the Meta for Developers dashboard on October 20, 2026.

- App: Rocketbox (`1836367217546891`)
- Submission ID: `1843836450133301`
- Overall result: **Some access requests not approved**
- [Submission feedback](https://developers.facebook.com/apps/1836367217546891/app-review/submissions/feedback/?submission_id=1843836450133301&business_id=1235592620332534)

The feedback page labels the request results “October 3, 2026 at 17:36 BST.” The previous-submissions list labels the submission “October 16, 2026 at 10:57 BST.” These are the dates displayed by Meta; their discrepancy has not been resolved.

## Permission results

| Permission | Result |
| --- | --- |
| `instagram_business_basic` | Rejected |
| `instagram_business_content_publish` | Rejected |
| `whatsapp_business_messaging` | Approved |
| `whatsapp_business_management` | Approved |
| `public_profile` | Approved |

## Why Instagram access was rejected

Both rejected permissions received the same feedback:

**Screencast Not Aligned with Use Case Details** — Developer Policy 1.6, Build a Trustworthy Product.

Meta states that the app's use case is allowed, but the submitted screencast does not demonstrate the complete end-to-end experience described in the submission notes. The feedback does not identify a particular missing scene or a specific application defect.

## Meta's requirements for resubmission

Submit a new screencast demonstrating:

1. The complete Meta login flow.
2. A user granting the app access to the requested permission or feature.
3. The complete end-to-end use case for each requested permission or feature.
4. English as the app UI language, with captions, tooltips, and explanations of relevant buttons and UI elements.
5. If the app uses server-to-server access or a system user token, explain this in the submission so reviewers understand why no frontend Meta login flow is visible.

For Rocketbox's Instagram permissions, the recording should follow the actual Instagram Login flow and demonstrate the connected account and successful publishing, matching the written submission notes. This is an implementation recommendation based on the feedback, not an additional reviewer finding.

Relevant Meta guidance:

- [Screen Recording Guide](https://developers.facebook.com/docs/app-review/submission-guide/screen-recordings)
- [Developer Policy](https://developers.facebook.com/devpolicy/)
- [Common rejection guidelines](https://developers.facebook.com/docs/app-review/support/rejection-guides/)

## Verification status

The dashboard separately shows:

- Business verification: **Verified** (Tadaaa Business).
- Access verification: **Verified** as a Tech Provider.

These verification processes are complete; the outstanding review issue is the evidence supplied for the two Instagram permission requests.

No resubmission or app configuration changes were made while inspecting these results.

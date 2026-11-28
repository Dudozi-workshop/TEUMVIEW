# Play Billing setup

Package: com.dudozi.teumview (approved).

Create two non-consumable one-time products in Play Console: teumview_skin_sage_glass and teumview_skin_midnight_blue. Proposed price KRW 1900 each. Do not activate sales until verification is ready.

Production verification must run on a trusted server with Google Play Developer API credentials stored server-side only. Verify package, product, purchase token, purchase state and entitlement ownership; handle duplicate tokens idempotently. Acknowledge only valid purchases, support pending/cancelled states, restore and refund/revocation reconciliation. Do not trust local preferences or backup files for ownership. Checkout remains disabled by default.

Owner setup: Play Console product creation, service account authorization, internal testing license accounts, signing. Never commit credentials.

Acceptance: valid purchase unlocks only matching skin; pending, invalid, cancelled and refunded purchases remain locked; restore works on reinstall; offline policy is explicitly defined and tested; prices are read from store product metadata. Current adapter is not a production verification service.

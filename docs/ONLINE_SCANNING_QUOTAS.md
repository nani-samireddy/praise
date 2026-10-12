# Online photo scanning and quotas

**Deferred / superseded:** On 12 October 2026 the user decided to remove all OCR and AI/text recognition for now, retaining local picture saving and manual entry. Do not implement or activate the provider/quota plan below. It is historical research for a possible future model decision. No scan quotas, Gemini credentials or online extraction service are needed for the current photo-only scope.

Decision recorded 12 October 2026; implementation dispatched to chat `01a13128-40a3-7311-995f-60c573d6b159`.

## Approved scope

- Remove offline text extraction and on-device song AI for now, including obsolete Tesseract/Gemma scanning dependencies, model downloads, and asset-pack build wiring. Preserve independent native metronome functionality.
- Keep local original-photo storage, manual song entry, recoverable drafts, and review before save.
- Use an online Gemini image-to-text adapter through a backend. The app must not contain the provider key.
- Enforce a configurable monthly allowance per installation, plus shared provider capacity limits on the backend.
- Expected audience: more than 500 monthly scanning users.
- No Gemini project exists yet. Production extraction must remain disabled until provider project, secret, model and verified free-tier limits are configured. Implement and test with fakes meanwhile.
- No sign-in initially. Installation identity is a soft limit and can reset on reinstall; it is not a reliable per-person limit. Global limits must remain effective despite new installation identities.

## Verified provider facts

Google documents Gemini limits per project rather than per API key. Relevant constraints include requests per minute, input tokens per minute and requests per day, varying by model and project. Current limits must be obtained from AI Studio; there is no publicly guaranteed universal number of free monthly image scans. RPD resets at midnight Pacific time. Unused daily capacity should not be treated as banked monthly credit.

Source: [Gemini API rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), checked 12 October 2026.

An alternative dedicated OCR service, Cloud Vision, documents the first 1,000 Document Text Detection units each month free. One image processed with that feature consumes one unit; additional features/pages and other project use change the accounting. This is an online OCR alternative, not a Gemini quota or an approved provider switch. Other hosting/resources can incur separate costs.

Source: [Cloud Vision pricing](https://cloud.google.com/vision/pricing), checked 12 October 2026.

Gemini unpaid-service data handling may permit submitted content to be used to improve products. Upload disclosure and privacy documentation must accurately reflect the selected service/tier and applicable terms; do not promise that images remain on-device or that server processing means zero retention.

Sources: [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing), [Gemini terms](https://ai.google.dev/gemini-api/terms).

## Allocation policy

No production per-installation allowance is finalized yet. Derive it from verified project capacity and the planned eligible installation count, with at least 20% reserved for retries, operational testing, uncertainty and other usage. Avoid changing an installation's displayed allowance unpredictably during the month; publish a configured cap for the period and expose shared-pool availability separately.

For planning, assuming one image needs one provider call:

`usable monthly equivalents = floor(free daily requests × days in month × 0.8)`

`monthly images per installation = floor(usable monthly equivalents / eligible installations)`

Divide further by measured provider calls per image when organization/retries use extra calls. Subtract other project usage explicitly. Token and minute limits can reduce practical capacity below the request-based estimate. These formulas are capacity estimates, not guaranteed service allocations; actual admissions must satisfy each provider window.

Illustrative alternative: 1,000 Cloud Vision OCR units minus 200 reserved units leaves 800 scans. At 500 installations this supports one scan each with spare capacity; at 800 it supports one each; at 1,000 it cannot guarantee even one each. Five scans per installation supports at most 160 fully using installations. This explains why a fixed five-scan promise would not fit an audience above 500 under that particular free pool.

Do not create extra keys/projects to evade provider quotas. Do not automatically fall back to a paid provider or enable billing changes.

## Backend acceptance requirements

- Authenticate a signed, server-issued installation identifier. Do not trust a client-supplied quota counter.
- Use atomic quota reservations and bounded concurrency for per-installation and shared counters. Do not use a non-atomic KV read/increment/write counter as the hard budget guard.
- Apply monthly user limits and provider day/minute/token limits before an upstream call. Model the provider Pacific daily reset separately from the user monthly window.
- Use calendar-month UTC for installation allowance periods and return a precise reset timestamp for localized UI display.
- Use request idempotency so network retries cannot duplicate an extraction or allowance charge.
- Successful extraction consumes installation allowance. Reconcile reservations on errors; provider attempts that may consume upstream quota still count toward shared capacity. Client cancellation does not imply an upstream call was cancelled or free.
- Enforce bounded image size, accepted formats, output schema, transcription preservation, timeouts and abuse limits.
- Refuse calls when capacity/configuration is unavailable. A spending dashboard alert is not a substitute for a hard admission cutoff.
- Return installation remaining/limit/reset and clear shared-pool unavailable states; no automatic unbounded retries.
- Keep photos and manual editing usable when offline, consent is declined, extraction fails, or quota is exhausted.
- Test concurrency, duplicate requests, reinstall identity multiplication, month/day rollover, provider rejection, malformed results, cancellation, and absent credentials.

## Setup still required

1. Create the intended Gemini project and select an image-input/text-output model suitable for Telugu transcription.
2. Record its actual free-tier RPM, TPM and RPD, and confirm applicable data handling and intended audience eligibility.
3. Benchmark representative Telugu song images to measure accuracy, latency, tokens and calls per scan.
4. Configure installation allowance, eligible installation planning count, provider budgets and secret storage on the backend.
5. Verify the backend has no paid fallback and blocks calls when its shared limits are exhausted; then run a small controlled live smoke test before enabling scanning.

No provider account, API key, billing setting or external deployment was created by this research update.

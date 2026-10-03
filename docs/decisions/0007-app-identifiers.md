# 0007 — Permanent application identifiers

- Status: proposed (T-0026, 2026-10-03). Requires Chris's explicit acceptance before the first
  production Play Console or App Store Connect app record/upload.
- Scope: store/application identity only. This does not choose the final store-facing product name.

## Proposal

Candidate neutral production identifier on both platforms:

- Android `applicationId`: `com.krystiangaleczka.wordgame`
- iOS bundle ID: `com.krystiangaleczka.wordgame`

Throwaway S1 apps use:

- Android `applicationId`: `com.krystiangaleczka.wordgame.spike`
- iOS bundle ID: `com.krystiangaleczka.wordgame.spike`

The `.spike` ID is disposable and never becomes the production app. It may be used by T-0027/T-0028
while this production identifier remains proposed.

## Rationale

- The candidate is independent of the working title "World of Words", so a later trademark/store-name
  change would not force a package identity change.
- Android and iOS would share the same base identifier to reduce cross-provider configuration mistakes.
- A dedicated `.spike` namespace keeps S1 receipts, analytics, ads and test signing separate.
- The production namespace contains the developer surname and becomes effectively permanent after the
  first store record/upload, so Sol must not mark it accepted without Chris's explicit approval.

## Consequences if accepted

- The first production Play Console and App Store Connect records use
  `com.krystiangaleczka.wordgame`.
- Later store-facing name changes do not change these identifiers.
- Provider config files must match the production or spike ID exactly.

## Before acceptance

Chris may accept this candidate or choose a different neutral reverse-DNS namespace. That decision
must happen before the first production store record/upload. Changing the throwaway `.spike` ID
does not migrate or reserve the production app.

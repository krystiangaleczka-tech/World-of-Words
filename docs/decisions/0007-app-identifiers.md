# 0007 — Permanent application identifiers

- Status: accepted (T-0026, 2026-10-03).
- Scope: store/application identity only. This does not choose the final store-facing product name.

## Decision

Use one neutral reverse-DNS identifier for the production app on both platforms:

- Android `applicationId`: `com.krystiangaleczka.wordgame`
- iOS bundle ID: `com.krystiangaleczka.wordgame`

Throwaway S1 apps use:

- Android `applicationId`: `com.krystiangaleczka.wordgame.spike`
- iOS bundle ID: `com.krystiangaleczka.wordgame.spike`

The `.spike` ID is never uploaded as the production app and never reused for production signing,
billing products, AdMob production units or Firebase production app registrations.

## Rationale

- The identifier is independent of the working title "World of Words", so a later trademark/store-name
  change does not force a package identity change.
- Android and iOS share the same base identifier to reduce configuration mistakes across SDK consoles.
- A dedicated `.spike` namespace prevents S1 test resources, receipts, analytics and ad configuration
  from contaminating the production app identity.
- Package/bundle identifiers are treated as permanent once the first store upload is made.

## Consequences

- T-0027 and T-0028 must use the `.spike` ID.
- The first real Play Console/App Store Connect app records must use `com.krystiangaleczka.wordgame`.
- Later store-facing name changes do not change these identifiers.
- Any provider config file committed later must correspond to the correct production or spike ID.

## Revisit if

Only before the first production store record/upload, and only if Chris explicitly changes the
developer namespace. After the first production upload, superseding this decision must not rename the
existing store app identifier.

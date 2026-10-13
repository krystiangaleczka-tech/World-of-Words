# T-0237 Owner review: bonus chest calibration

Status: awaiting owner decision. No economy values changed.

## Comparable scenario

300 completed levels, zero initial wallet, 10 levels/session, one synthetic session/day,
one eligible bonus/level, free onboarding inventory enabled, no purchase. Ads are explicitly
requested/assumed permitted and available only in the ad_watcher policy. These are hypotheses,
not observed device/player data. Only bonus.chest.words_required differs between the two runs.

| Policy | Threshold | Chests | Final coins | Unfulfilled tool requests |
|---|---:|---:|---:|---:|
| saver | 10 | 29 | 10400 | 0 |
| saver | 20 | 14 | 8900 | 0 |
| hinter | 10 | 29 | 100 | 217 |
| hinter | 20 | 14 | 100 | 232 |
| ad_watcher | 10 | 29 | 13375 | 0 |
| ad_watcher | 20 | 14 | 11875 | 0 |

20 bonuses approximate two steady synthetic sessions/chest (initial unlock delays the first).
The lower payout frequency increases unfulfilled tool requests; they never block completion.
Base25/Hint100 retains four base completions per Hint; Reveal250/Hint100 stays 2.5;
chest100 and rewarded100 retain one-Hint coin equivalents. No change to these values is proposed.

## Owner choices

- 20: accept a model-based starting calibration; update only threshold/default documentation/tests.
- 10: retain current starting values until bonus/session discovery is observed on device.

No option is evidence that retention, total affordability or actual chest cadence is established.
The recorded T-0203 historical baseline remains unchanged. Applying either disposition waits for
explicit owner answer to the pending question. T-0236 is merged; dependency status reconciled.

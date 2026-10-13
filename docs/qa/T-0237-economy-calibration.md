# T-0237 Owner review: bonus chest calibration

Status: owner approved retaining threshold10 ("10, ok"). No economy values changed.

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
The recorded T-0203 historical baseline remains unchanged. Owner disposition is recorded below. T-0236 is merged; dependency status reconciled.

## Accepted disposition

Chris chose 10; retain current defaults until actual session/bonus discovery evidence supports
retuning. The synthetic two-session hypothesis does not justify reducing chest frequency now.
No config, gameplay, Save, historical decision or existing test changes are required.

## Validation

Full make check passed after disposition: 451 Godot, 311 pipeline and 488 tools tests.
Twenty-one simulator tests pass; shipped P2 defaults include bonus threshold10.
No config files changed. Task metadata and scope checks passed. Independent review remains required.

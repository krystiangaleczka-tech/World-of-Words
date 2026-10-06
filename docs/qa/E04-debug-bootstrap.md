# Five-task continuation — Phase 0 debug bootstrap

Chris requested the next five tasks after the documented T-0048 prerequisite block. Execute and merge
sequentially: T-0054 provisional token subset, T-0055 catalog components/gallery, T-0056 Save reset,
T-0057 debug routing, T-0048 screen. R-UI-1 is respected by a separate component task.

This explicit bootstrap uses existing provisional DESIGN values, not a new visual direction. Full
T-0103 tokens/motion and P2 theme/accessibility/component versions stay deferred; their future preflight
must account for the minimal subset now present. ROADMAP is unchanged. No Phase 0 exit is claimed.

Save reset is debug-only and explicitly confirmed by a developer. It resets only progress/economy/daily
from SaveSchema defaults and retains identity, settings and all monetization records. Isolated fixtures
and storage fault injection verify it; real player data is never reset by tests or boot.

The current dry run uses Codex with independent fresh reviews. It does not fabricate cheap-model gate
participation, Chris review minutes, device appearance approval or release-artifact exclusion evidence.
T-0031 and the Phase 0 exit remain separate gates.

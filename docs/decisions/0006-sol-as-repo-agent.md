# 0006 — GPT-5.6 Sol works directly on the repo

- Status: accepted (Chris, 2026-10-01: Sol can work directly via ChatGPT + GitHub MCP; stronger models
  can be used for heavy tasks)
- Context: design pass `05-workflow-ai.md` §2, spike S5 (now resolved).

## Decision
- Sol (ChatGPT, GitHub MCP) reads the repo directly, writes task files, opens branches/PRs and reviews PRs.
  No more manual context pasting for Sol; `tools/context_pack.py` stays useful for cheap executors and Opus.
- Sol implements `contract`, `infra`, `docs` and complex `feat` tasks itself instead of over-specifying them
  for cheap models.
- Limitation: Sol in chat has no local Godot/Python runtime. Its test loop is CI. Tasks that need fast
  iterate-run-fix cycles (game feel, Godot scenes, flaky platform work) go to an executor with a runtime
  (cheap agent in the Docker image, or Opus in Claude Code) or to Chris.
- Cheap executors (Gemini Flash, GPT Luna) keep: well-specified `feat`, `test`, `refactor`, `content`,
  rebases and re-runs.
- Opus stays a second opinion for irreversible decisions + visual/UX foundation (design pass §2).

## Consequences
- The "spec tax" drops: fewer ultra-detailed tasks; tasks for Sol can be shorter.
- CI must be fast and give readable failure output, because it is Sol's only feedback loop.

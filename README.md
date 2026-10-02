# World of Words (working title)

Mobile word-connect puzzle game for Android and iOS. Phase 0 (Foundation) in progress; no game code yet.

Where to read:
- `docs/PRODUCT.md`: product requirements (canonical for config keys, event names, IAP IDs)
- `docs/DESIGN.md`: design system and UX flows
- `tasks/ROADMAP.md`: all tasks with dependencies, lanes, executor and thinking level
- `docs/decisions/`: accepted decisions
- `docs/design-pass/`: read-only architecture and design pass (Polish); the files above win on conflicts

## Run the project
- Engine: Godot **4.7.2-stable**, standard build (decision 0001). Use exactly this version.
- Open `game/project.godot` in the editor, or import headless: `godot --headless --path game --import --quit`.
- Agents: read `AGENTS.md` first. `make check` and the Docker image arrive with T-0014 … T-0017.

Layout: `game/` (Godot project), `pipeline/` (Python content pipeline), `tools/` (task and CI tools),
`docs/`, `tasks/`. Details in `docs/ARCHITECTURE.md#areas`.

# T-0150 — Android build versioning

Local Android exports collect the task ID, task name and timezone-aware build
timestamp before starting Godot. GitHub Actions resolves the task from its branch
or commit and records the matching task title and runner time. Both export jobs
upload `builds/build-versioning.json`; each report also carries its build record.

No automated tests were added or run for this change. The task reviewer should
run each supported export in a terminal and confirm the metadata prompt, rejected
wrong task/title, accepted timezone-aware timestamp, and appended artifact record.

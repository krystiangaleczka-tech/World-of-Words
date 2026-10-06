# World of Words developer entry points (T-0017). CI and agents run the same targets.
# A target whose inputs do not exist yet prints SKIP and succeeds; it never skips silently.

GODOT ?= godot
UV ?= uv
GAME := game
GD_SRC := $(shell find $(GAME) -name '*.gd' -not -path '$(GAME)/addons/*' -not -path '$(GAME)/.godot/*')
LOG := /tmp/wow-godot-import.log
GUT_LOG := /tmp/wow-gut-tests.log

skip = @echo "SKIP $@: $(1)"

.PHONY: check test lint fmt fmt-check run import pipeline-test tools-test content-validate \
        registries context review board plan

check: fmt-check lint import test pipeline-test tools-test registries content-validate
	@echo "make check: OK"

import:
	@$(GODOT) --headless --path $(GAME) --import --quit > $(LOG) 2>&1; status=$$?; \
	if grep -E '^(ERROR|SCRIPT ERROR|WARNING)' $(LOG); then echo "import log has errors/warnings ($(LOG))"; exit 1; fi; \
	exit $$status

test: import
	@$(GODOT) --headless --path $(GAME) -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json > $(GUT_LOG) 2>&1; status=$$?; \
	cat $(GUT_LOG); \
	if grep -qE '^(SCRIPT ERROR:|ERROR: Failed to load script)' $(GUT_LOG); then \
		echo "GUT script loading/runtime error ($(GUT_LOG))"; exit 1; fi; \
	exit $$status

fmt:
	$(UV) run gdformat $(GD_SRC)
	$(UV) run ruff format .
	$(UV) run ruff check --fix .

fmt-check:
	$(UV) run gdformat --check $(GD_SRC)
	$(UV) run ruff format --check .

lint:
	$(UV) run gdlint $(GD_SRC)
	$(UV) run ruff check .

run:
	$(GODOT) --path $(GAME)

pipeline-test:
	$(UV) run pytest pipeline/tests

tools-test:
	$(UV) run pytest tools/tests

content-validate:
	$(if $(wildcard pipeline/src/wow_pipeline/validate.py),$(UV) run python -m wow_pipeline.validate,$(call skip,pipeline validator not written yet (E05)))

registries:
	$(UV) run python tools/check_registries.py

context:
	$(if $(wildcard tools/context_pack.py),$(UV) run python tools/context_pack.py,$(call skip,tools/context_pack.py not written yet))

review:
	$(if $(wildcard tools/review_pack.py),$(UV) run python tools/review_pack.py $(T),$(call skip,tools/review_pack.py not written yet))

board:
	$(if $(wildcard tools/tasks.py),$(UV) run python tools/tasks.py board,$(call skip,tools/tasks.py not written yet (T-0019)))

plan:
	$(if $(wildcard tools/tasks.py),$(UV) run python tools/tasks.py plan,$(call skip,tools/tasks.py not written yet (T-0019)))

"""Reject direct literal player copy in feature/component UI sinks."""

from ui_checks import main

if __name__ == "__main__":
    raise SystemExit(main("strings"))

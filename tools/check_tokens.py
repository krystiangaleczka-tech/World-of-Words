"""Reject direct raw visual values in feature/component UI syntax."""

from ui_checks import main

if __name__ == "__main__":
    raise SystemExit(main("tokens"))

"""Offline duplicate/repetition analysis; unactivated in the P1 pipeline."""

from .core import CROSSWORD_SPACING, DuplicateConflict, DuplicatePolicy, audit_duplicates

__all__ = ["CROSSWORD_SPACING", "DuplicateConflict", "DuplicatePolicy", "audit_duplicates"]

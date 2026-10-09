"""Deterministic multiset lookup; discovery does not select a crossword layout."""

from collections import Counter, defaultdict
from itertools import product

from ..config import LanguageConfig
from ..tiers.core import valid_word


class WordIndex:
    def __init__(self, records: object, config: LanguageConfig) -> None:
        if not isinstance(records, list):
            raise ValueError("Candidate records must be a list")
        self.config = config
        self.tiers: dict[str, str] = {}
        self.index: dict[str, list[str]] = defaultdict(list)
        previous = ""
        for record in records:
            if not isinstance(record, dict):
                raise ValueError("Malformed tier record")
            word, tier = record.get("word"), record.get("tier")
            if not valid_word(word, config) or word <= previous:
                raise ValueError("Tier words must be normalized, sorted and unique")
            if tier not in ("level_ok", "bonus_ok", "banned"):
                raise ValueError("Unknown candidate tier")
            previous = word
            self.tiers[word] = tier
            if tier != "banned":
                self.index["".join(sorted(word))].append(word)

    def pools(self, letters: object) -> dict[str, list[str]]:
        if (
            not isinstance(letters, list)
            or not self.config.min_length <= len(letters) <= self.config.max_length
            or any(
                not isinstance(c, str) or len(c) != 1 or c not in self.config.alphabet
                for c in letters
            )
        ):
            raise ValueError("Invalid wheel letters")
        counts = sorted(Counter(letters).items())
        pools: dict[str, list[str]] = {"level_ok": [], "bonus_ok": []}
        for sizes in product(*(range(count + 1) for _, count in counts)):
            if sum(sizes) < self.config.min_length:
                continue
            signature = "".join(char * size for (char, _), size in zip(counts, sizes, strict=True))
            for word in self.index.get(signature, ()):
                pools[self.tiers[word]].append(word)
        return {tier: sorted(words) for tier, words in pools.items()}

    def automatic(self) -> list[dict[str, object]]:
        seeds: dict[str, list[str]] = defaultdict(list)
        for word, tier in self.tiers.items():
            if tier == "level_ok":
                seeds["".join(sorted(word))].append(word)
        return [
            {
                "id": "pl-auto-" + signature,
                "letters": list(signature),
                "seeds": words,
                **self.pools(list(signature)),
            }
            for signature, words in sorted(seeds.items())
        ]

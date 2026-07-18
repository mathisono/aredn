#!/usr/bin/env python3
"""Executable policy tests for PollyWAN's simplified selection invariants."""

from dataclasses import dataclass

CLASS_SCORE = {"unknown": 1, "low": 2, "medium": 3, "fast": 4}


@dataclass(frozen=True)
class Candidate:
    name: str
    configured: bool = True
    healthy: bool = True
    speed_class: str = "unknown"
    fresh: bool = True

    @property
    def class_for_selection(self) -> str:
        return self.speed_class if self.fresh else "unknown"

    @property
    def score(self) -> int:
        if not self.configured or not self.healthy:
            return 0
        return CLASS_SCORE[self.class_for_selection]


def automatic_choice(candidates: list[Candidate], current: str, preferred: str) -> str | None:
    healthy = [c for c in candidates if c.score > 0]
    if not healthy:
        return None
    current_candidate = next((c for c in healthy if c.name == current), None)
    best_score = max(c.score for c in healthy)
    if current_candidate and current_candidate.score == best_score:
        return current
    tied = [c for c in healthy if c.score == best_score]
    if best_score == CLASS_SCORE["unknown"]:
        return preferred if any(c.name == preferred for c in tied) else tied[0].name
    if any(c.name == preferred for c in tied):
        return preferred
    for name in ("wan", "wan2", "wan3"):
        if any(c.name == name for c in tied):
            return name
    return tied[0].name


def manual_choice(candidates: list[Candidate], selected: str, preferred: str) -> str | None:
    selected_candidate = next((c for c in candidates if c.name == selected), None)
    if selected_candidate and selected_candidate.healthy and selected_candidate.configured:
        return selected
    for name in (preferred, "wan", "wan2", "wan3"):
        fallback = next((c for c in candidates if c.name == name), None)
        if fallback and fallback.healthy and fallback.configured:
            return fallback.name
    return None


def promotion_ready(active: Candidate, target: Candidate, observations: int) -> bool:
    if active.score == 0:
        return target.score > 0
    return target.score > active.score and observations >= 2


def main() -> None:
    assert manual_choice([Candidate("wan"), Candidate("wan2")], "wan", "wan2") == "wan"
    assert manual_choice([Candidate("wan", healthy=False), Candidate("wan2")], "wan", "wan2") == "wan2"

    assert automatic_choice(
        [Candidate("wan", speed_class="medium"), Candidate("wan2", speed_class="medium")],
        "wan",
        "wan2",
    ) == "wan"
    assert not promotion_ready(Candidate("wan", speed_class="medium"), Candidate("wan2", speed_class="fast"), 1)
    assert promotion_ready(Candidate("wan", speed_class="medium"), Candidate("wan2", speed_class="fast"), 2)
    assert promotion_ready(Candidate("wan", healthy=False, speed_class="fast"), Candidate("wan2", speed_class="low"), 0)

    assert automatic_choice(
        [Candidate("wan", speed_class="fast", fresh=False), Candidate("wan2", speed_class="medium", fresh=False)],
        "mesh",
        "wan2",
    ) == "wan2"
    assert Candidate("wan", healthy=True, fresh=False, speed_class="fast").score == CLASS_SCORE["unknown"]
    assert Candidate("wan", healthy=True, fresh=True, speed_class="unknown").score == CLASS_SCORE["unknown"]

    # A failed speed test is modelled as an unknown class, not a failed health check.
    assert automatic_choice(
        [Candidate("wan", speed_class="unknown"), Candidate("wan2", speed_class="medium")],
        "wan",
        "wan",
    ) == "wan2"
    assert CLASS_SCORE["low"] < CLASS_SCORE["medium"] < CLASS_SCORE["fast"]
    assert {"manual": "manual", "availability": "automatic", "adaptive": "automatic"}["adaptive"] == "automatic"

    print("simplified selection policy model passed")


if __name__ == "__main__":
    main()

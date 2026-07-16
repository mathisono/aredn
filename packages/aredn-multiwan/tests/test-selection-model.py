#!/usr/bin/env python3
"""Executable policy tests for PollyWAN's documented selection invariants."""

from dataclasses import dataclass

BIN_SCORE = {"unknown": 0, "low": 1, "medium": 2, "fast": 3}


@dataclass(frozen=True)
class Candidate:
    name: str
    configured: bool = True
    healthy: bool = True
    bin: str = "unknown"
    fresh: bool = True

    @property
    def score(self) -> int:
        if not self.configured or not self.healthy or not self.fresh:
            return 0
        return BIN_SCORE[self.bin]


def choose(candidates: list[Candidate], preferred: str) -> str | None:
    eligible = [c for c in candidates if c.score > 0]
    if not eligible:
        return None
    best_score = max(c.score for c in eligible)
    tied = [c for c in eligible if c.score == best_score]
    for candidate in tied:
        if candidate.name == preferred:
            return candidate.name
    return tied[0].name


def promotion_sequence(
    active: Candidate,
    target: Candidate,
    preferred: str,
    promote_count: int,
    hold_down_elapsed: bool,
    observations: int,
) -> bool:
    if active.score == 0:
        return target.score > 0  # hard failure: immediate
    better = target.score > active.score or (
        target.score == active.score and target.name == preferred
    )
    return better and hold_down_elapsed and observations >= promote_count


def main() -> None:
    assert choose(
        [Candidate("wan", bin="medium"), Candidate("wan2", bin="fast")],
        "wan",
    ) == "wan2"
    assert choose(
        [Candidate("wan", bin="medium"), Candidate("wan2", bin="medium")],
        "wan",
    ) == "wan"
    assert choose(
        [Candidate("wan", healthy=False, bin="fast"), Candidate("wan2", bin="low")],
        "wan",
    ) == "wan2"
    assert choose(
        [Candidate("wan", fresh=False, bin="fast"), Candidate("wan2", bin="medium")],
        "wan",
    ) == "wan2"
    assert choose(
        [Candidate("wan", configured=False), Candidate("wan2", healthy=False)],
        "wan",
    ) is None

    active = Candidate("wan", bin="medium")
    target = Candidate("wan2", bin="fast")
    assert not promotion_sequence(active, target, "wan", 2, True, 1)
    assert promotion_sequence(active, target, "wan", 2, True, 2)
    assert not promotion_sequence(active, target, "wan", 2, False, 5)

    failed_active = Candidate("wan", healthy=False, bin="fast")
    assert promotion_sequence(failed_active, Candidate("wan2", bin="low"), "wan", 5, False, 0)

    same = Candidate("wan2", bin="medium")
    assert promotion_sequence(active, same, "wan2", 2, True, 2)
    assert not promotion_sequence(active, same, "wan", 2, True, 5)

    # A local route may remain usable at low speed while the default mesh-share
    # policy keeps table 28 unpublished until medium or better.
    assert BIN_SCORE["low"] < BIN_SCORE["medium"]

    print("selection policy model passed")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Executable policy tests for R29.5 ordered route selection."""

from dataclasses import dataclass

CLASS_SCORE = {"unknown": 1, "low": 2, "medium": 3, "fast": 4}


@dataclass(frozen=True)
class Candidate:
    name: str
    enabled: bool = True
    healthy: bool = True
    speed_class: str = "unknown"
    fresh: bool = True
    remote_mesh: bool = False

    def eligible(self, minimum: str = "low") -> bool:
        if not self.enabled or not self.healthy:
            return False
        if self.remote_mesh:
            return True
        score = CLASS_SCORE[self.speed_class if self.fresh else "unknown"]
        floor = CLASS_SCORE[minimum]
        return (floor <= CLASS_SCORE["low"] and score == CLASS_SCORE["unknown"]) or score >= floor


def ordered_choice(candidates: list[Candidate], order: list[str], minimum: str = "low") -> str | None:
    by_name = {candidate.name: candidate for candidate in candidates}
    for name in order:
        candidate = by_name.get(name)
        if candidate and candidate.eligible(minimum):
            return name
    return None


def recovery_ready(active: str, target: str, order: list[str], observations: int, hold_down_done: bool) -> bool:
    if active not in order or target not in order:
        return False
    return order.index(target) < order.index(active) and observations >= 2 and hold_down_done


def main() -> None:
    order = ["wan", "wan2", "wan3", "mesh"]
    all_up = [Candidate("wan"), Candidate("wan2"), Candidate("wan3"), Candidate("mesh", remote_mesh=True)]
    assert ordered_choice(all_up, order) == "wan"

    a_down = [Candidate("wan", healthy=False), Candidate("wan2"), Candidate("wan3"), Candidate("mesh", remote_mesh=True)]
    assert ordered_choice(a_down, order) == "wan2"
    a_b_down = [Candidate("wan", healthy=False), Candidate("wan2", healthy=False), Candidate("wan3"), Candidate("mesh", remote_mesh=True)]
    assert ordered_choice(a_b_down, order) == "wan3"
    local_down = [Candidate("wan", healthy=False), Candidate("wan2", healthy=False), Candidate("wan3", healthy=False), Candidate("mesh", remote_mesh=True)]
    assert ordered_choice(local_down, order) == "mesh"
    assert ordered_choice([Candidate("mesh", enabled=False, remote_mesh=True)], order) is None

    # Speed is an eligibility floor, never a ranking input.
    assert ordered_choice([Candidate("wan", speed_class="low"), Candidate("wan2", speed_class="fast")], order) == "wan"
    assert ordered_choice([Candidate("wan", speed_class="low"), Candidate("wan2", speed_class="fast")], order, "medium") == "wan2"
    assert ordered_choice([Candidate("wan", fresh=False), Candidate("mesh", remote_mesh=True)], order, "medium") == "mesh"

    # Fail downward immediately; return upward only after confirmation and hold-down.
    assert not recovery_ready("wan3", "wan2", order, 1, True)
    assert not recovery_ready("wan3", "wan2", order, 2, False)
    assert recovery_ready("wan3", "wan2", order, 2, True)
    assert recovery_ready("wan2", "wan", order, 2, True)
    assert not recovery_ready("wan2", "wan3", order, 2, True)

    print("ordered route policy model passed")


if __name__ == "__main__":
    main()

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timedelta, timezone
from math import pow


@dataclass(frozen=True)
class GameStats:
    slug: str
    category: str | None = None
    rating: int | None = None
    matches: int | None = None
    wins: int | None = None
    draws: int | None = None
    losses: int | None = None

    def as_dict(self) -> dict[str, object]:
        values = asdict(self)
        if self.matches:
            for result in ("wins", "draws", "losses"):
                amount = values[result]
                values[f"{result}_percent"] = round(100 * amount / self.matches, 1) if amount is not None else None
        return values


@dataclass(frozen=True)
class PlayerProfile:
    name: str
    gender: str | None = None
    age: str | None = None
    country: str | None = None
    status: str | None = None
    room: str | None = None
    games: dict[str, GameStats] = field(default_factory=dict)

    def as_dict(self) -> dict[str, object]:
        return {**asdict(self), "games": {name: game.as_dict() for name, game in self.games.items()}}


@dataclass(frozen=True)
class RatingProjection:
    probability: float
    win_rating: int
    draw_rating: int
    loss_rating: int
    zero_date: date
    zero_days: int


def expected_score(player_rating: int, opponent_rating: int) -> float:
    """Return the player's Elo expected score (not just the higher player's score)."""
    return 1 / (1 + pow(10, (opponent_rating - player_rating) / 400))


# FlyOrDie caps a one-game series at 16 for every rating band, and the app
# always models a single match between the two players.
SINGLE_MATCH_K = 16


def projected_rating(rating: int, opponent_rating: int, score: float) -> int:
    """Apply a single Elo outcome: 1 for win, 0.5 draw, and 0 loss."""
    return max(0, round(rating + SINGLE_MATCH_K * (score - expected_score(rating, opponent_rating))))


def days_to_zero(rating: int) -> int:
    """Apply FlyOrDie's published daily decay rule without a date-dependent side effect."""
    days = 0
    remaining = rating
    while remaining >= 0:
        remaining -= 1 if remaining <= 353 else round(remaining**2 / 125000)
        days += 1
    return days


def project(rating: int, opponent_rating: int, today: date | None = None) -> RatingProjection:
    days = days_to_zero(rating)
    return RatingProjection(
        probability=expected_score(rating, opponent_rating),
        win_rating=projected_rating(rating, opponent_rating, 1),
        draw_rating=projected_rating(rating, opponent_rating, 0.5),
        loss_rating=projected_rating(rating, opponent_rating, 0),
        zero_days=days,
        zero_date=(today or datetime.now(timezone.utc).date()) + timedelta(days=days),
    )

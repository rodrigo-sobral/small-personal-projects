from __future__ import annotations

from pathlib import Path

import yaml

from .domain import GameStats, PlayerProfile
from .paths import data_directory

NUMERIC_FIELDS = ("rating", "matches", "wins", "draws", "losses")
TEXT_FIELDS = ("gender", "age", "country", "status", "room")


class PlayerDataError(ValueError):
    """Raised when a player file cannot be trusted, with a readable reason."""


def _as_int(value: object, label: str) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise PlayerDataError(f"{label} must be a whole number, but is {value!r}.") from exc


def _as_text(value: object) -> str | None:
    return None if value is None else str(value)


class PlayerStore:
    """Persist all known player profiles in one human-readable YAML file."""

    def __init__(self, path: Path | None = None) -> None:
        self.path = path or data_directory() / "players" / "players.yaml"

    def load(self) -> dict[str, PlayerProfile]:
        if not self.path.exists():
            return {}
        with self.path.open("r", encoding="utf-8") as handle:
            document = yaml.safe_load(handle) or {}
        raw_players = document.get("players", {})
        if not isinstance(raw_players, dict):
            return {}
        return {
            str(key): self._profile_from_dict(str(key), value)
            for key, value in raw_players.items()
            if isinstance(value, dict)
        }

    def save(self, profiles: dict[str, PlayerProfile]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        document = {"players": {name: profile.as_dict() for name, profile in sorted(profiles.items())}}
        with self.path.open("w", encoding="utf-8") as handle:
            yaml.safe_dump(document, handle, allow_unicode=False, sort_keys=False)

    def read_validated(self) -> dict[str, PlayerProfile]:
        """Load a user-chosen file strictly, rejecting anything malformed.

        ``load`` stays forgiving because it reads the file this app wrote.  An
        imported file is unknown input, so every field is checked and a bad one
        aborts the whole import instead of silently dropping players.
        """
        try:
            with self.path.open("r", encoding="utf-8") as handle:
                document = yaml.safe_load(handle)
        except yaml.YAMLError as exc:
            raise PlayerDataError(f"The file is not valid YAML: {exc}.") from exc
        if not isinstance(document, dict):
            raise PlayerDataError("The file must contain a mapping of players.")
        raw_players = document.get("players", document)
        if not isinstance(raw_players, dict) or not raw_players:
            raise PlayerDataError("The file contains no players.")
        profiles: dict[str, PlayerProfile] = {}
        for key, value in raw_players.items():
            name = str(key).strip()
            if not name:
                raise PlayerDataError("A player entry has an empty name.")
            if not isinstance(value, dict):
                raise PlayerDataError(f"The entry for {name} must be a mapping of player fields.")
            profiles[name] = self._validated_profile(name, value)
        return profiles

    @classmethod
    def _validated_profile(cls, name: str, data: dict[str, object]) -> PlayerProfile:
        raw_games = data.get("games")
        if not isinstance(raw_games, dict) or not raw_games:
            raise PlayerDataError(f"{name} has no games.")
        games: dict[str, GameStats] = {}
        for slug, game in raw_games.items():
            game_name = str(slug).strip()
            if not game_name:
                raise PlayerDataError(f"{name} has a game with an empty name.")
            if not isinstance(game, dict):
                raise PlayerDataError(f"The game {game_name} of {name} must be a mapping of statistics.")
            numbers = {
                field: _as_int(game.get(field), f"{name} / {game_name} / {field}") for field in NUMERIC_FIELDS
            }
            games[game_name] = GameStats(slug=game_name, category=_as_text(game.get("category")), **numbers)
        return PlayerProfile(
            name=str(data.get("name") or name),
            games=games,
            **{field: _as_text(data.get(field)) for field in TEXT_FIELDS},
        )

    def merge(self, profile: PlayerProfile) -> dict[str, PlayerProfile]:
        profiles = self.load()
        existing_key = next((key for key in profiles if key.casefold() == profile.name.casefold()), profile.name)
        profiles[existing_key] = profile
        self.save(profiles)
        return profiles

    @staticmethod
    def _profile_from_dict(name: str, data: dict[str, object]) -> PlayerProfile:
        raw_games = data.get("games", {})
        game_fields = {"slug", "category", "rating", "matches", "wins", "draws", "losses"}
        games = {
            slug: GameStats(**{key: value for key, value in game.items() if key in game_fields})
            for slug, game in raw_games.items()
            if isinstance(slug, str) and isinstance(game, dict)
        } if isinstance(raw_games, dict) else {}
        return PlayerProfile(
            name=str(data.get("name") or name),
            gender=data.get("gender"),
            age=data.get("age"),
            country=data.get("country"),
            status=data.get("status"),
            room=data.get("room"),
            games=games,
        )

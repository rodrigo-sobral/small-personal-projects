from __future__ import annotations

import logging
import re
import time
from dataclasses import replace
from urllib.parse import quote

import requests
from bs4 import BeautifulSoup

from .domain import GameStats, PlayerProfile

logger = logging.getLogger(__name__)


class FlyOrDieError(RuntimeError):
    pass


class FlyOrDieClient:
    """Small, timeout-bound client for public FlyOrDie player pages."""

    BASE_URL = "https://games.flyordie.com/players"

    def __init__(self, session: requests.Session | None = None, cache_seconds: int = 600) -> None:
        self.session = session or requests.Session()
        self.session.headers.setdefault("User-Agent", "FlyOrDie/1.0 (personal desktop client)")
        self.cache_seconds = cache_seconds
        self._cache: dict[str, tuple[float, PlayerProfile]] = {}

    def profile(self, name: str) -> PlayerProfile:
        clean_name = name.strip()
        if not clean_name:
            raise FlyOrDieError("A player name is required.")
        key = clean_name.casefold()
        cached = self._cache.get(key)
        if cached and time.monotonic() - cached[0] < self.cache_seconds:
            logger.info("Using cached public profile lookup")
            return cached[1]

        player_url = f"{self.BASE_URL}/{quote(clean_name, safe='')}"
        logger.info("Retrieving public player profile")
        soup = self._get_soup(player_url)
        profile = self._parse_profile(clean_name, soup)
        games: dict[str, GameStats] = {}
        for slug in self._game_slugs(soup):
            try:
                game = self._parse_game(slug, self._get_soup(f"{player_url}/{quote(slug, safe='')}"))
                games[slug] = game
            except FlyOrDieError:
                # A removed/restricted game must not discard the usable profile.
                logger.warning("Skipped an unavailable game page")
                continue
        if not games:
            raise FlyOrDieError("No public game statistics were found for this player.")
        profile = replace(profile, games=games)
        self._cache[key] = (time.monotonic(), profile)
        logger.info("Retrieved profile with %d readable game(s)", len(games))
        return profile

    def clear_cache(self) -> None:
        self._cache.clear()
        logger.info("Cleared public profile cache")

    def _get_soup(self, url: str) -> BeautifulSoup:
        try:
            response = self.session.get(url, timeout=(5, 20))
            response.raise_for_status()
        except requests.RequestException as exc:
            logger.warning("Public FlyOrDie request failed: %s", exc)
            raise FlyOrDieError(f"Could not retrieve public FlyOrDie data ({exc}).") from exc
        return BeautifulSoup(response.text, "html.parser")

    @staticmethod
    def _text(soup: BeautifulSoup, selector: str) -> str | None:
        node = soup.select_one(selector)
        return node.get_text(" ", strip=True) if node else None

    def _parse_profile(self, name: str, soup: BeautifulSoup) -> PlayerProfile:
        return PlayerProfile(
            name=name,
            gender=self._text(soup, "div.gender"),
            age=self._text(soup, "div.age"),
            country=self._text(soup, "div.c-l"),
            status=self._text(soup, ".currently-online-caption") or self._text(soup, ".status"),
            room=self._text(soup, ".current-room-caption"),
        )

    @staticmethod
    def _game_slugs(soup: BeautifulSoup) -> list[str]:
        links = soup.select("div.gameList a[href], .gameList a[href]")
        slugs: list[str] = []
        for link in links:
            href = link.get("href", "")
            slug = href.rstrip("/").split("/")[-1]
            if slug and re.fullmatch(r"[A-Za-z0-9_-]+", slug) and slug not in slugs:
                slugs.append(slug)
        return slugs

    def _parse_game(self, slug: str, soup: BeautifulSoup) -> GameStats:
        # The current page has a semantic rating column; the positional fallback
        # remains for old public pages that predate that markup.
        rating_text = (
            self._text(soup, ".ratingCol .w.H")
            or self._text(soup, ".rating")
            or self._legacy_rating(soup)
        )
        rating = self._number(rating_text)
        matches = self._number(self._text(soup, "td.matchCount"))
        wins = self._number(self._text(soup, ".winCount"))
        category = self._text(soup, ".ratingCategoryName")
        if rating is None:
            raise FlyOrDieError(f"The rating for {slug} could not be read.")
        draws, losses = self._pie_results(soup, matches, wins)
        return GameStats(slug, category, rating, matches, wins, draws, losses)

    @staticmethod
    def _legacy_rating(soup: BeautifulSoup) -> str | None:
        values = soup.select("div.w.H")
        return values[3].get_text(" ", strip=True) if len(values) > 3 else None

    @staticmethod
    def _number(value: str | None) -> int | None:
        if not value:
            return None
        match = re.search(r"[+-]?\d[\d,\.]*", value)
        return int(re.sub(r"[^\d-]", "", match.group(0))) if match else None

    @staticmethod
    def _pie_results(soup: BeautifulSoup, matches: int | None, wins: int | None) -> tuple[int | None, int | None]:
        if not matches or wins is None:
            return None, None
        # New markup may expose counts directly; the old markup only has pie angles.
        draws = FlyOrDieClient._number(FlyOrDieClient._node_text(soup, ".drawCount"))
        losses = FlyOrDieClient._number(FlyOrDieClient._node_text(soup, ".lossCount"))
        if draws is not None and losses is not None:
            return draws, losses
        return None, max(0, matches - wins)  # avoids inventing a draw split from fragile CSS angles

    @staticmethod
    def _node_text(soup: BeautifulSoup, selector: str) -> str | None:
        node = soup.select_one(selector)
        return node.get_text(" ", strip=True) if node else None

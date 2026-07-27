from flyordie.client import FlyOrDieClient
from flyordie.domain import GameStats, PlayerProfile


def test_game_parser_reads_legacy_markup() -> None:
    # Parsing helpers deliberately support the selectors used by the legacy client.
    from bs4 import BeautifulSoup
    page = BeautifulSoup('''<div class="l ratingCategoryName">Standard</div><div class="w H">a</div><div class="w H">b</div><div class="w H">c</div><div class="w H">1,234</div><td class="w matchCount">50</td><div class="w winCount H">30</div>''', "html.parser")
    game = FlyOrDieClient()._parse_game("chess", page)
    assert (game.slug, game.rating, game.matches, game.wins, game.losses) == ("chess", 1234, 50, 30, 20)


def test_game_parser_reads_current_rating_column() -> None:
    from bs4 import BeautifulSoup

    page = BeautifulSoup(
        '''<div class="ratingCol"><div class="w H">176</div></div>
        <div class="l ratingCategoryName">Advanced</div><td class="w matchCount">5,207</td>
        <div class="w winCount H">(2,327)</div>''',
        "html.parser",
    )
    game = FlyOrDieClient()._parse_game("CheckersBullet", page)
    assert (game.rating, game.matches, game.wins, game.losses) == (176, 5207, 2327, 2880)


def test_profile_maps_game_slugs_to_game_stats(monkeypatch) -> None:
    """A successful lookup must make game names sortable string keys for the UI."""
    from bs4 import BeautifulSoup

    client = FlyOrDieClient()
    monkeypatch.setattr(client, "_get_soup", lambda _: BeautifulSoup("<html></html>", "html.parser"))
    monkeypatch.setattr(client, "_parse_profile", lambda name, _: PlayerProfile(name))
    monkeypatch.setattr(client, "_game_slugs", lambda _: ["Draughts", "Checkers"])
    monkeypatch.setattr(client, "_parse_game", lambda slug, _: GameStats(slug, rating=100))

    profile = client.profile("Mike05")

    assert sorted(profile.games) == ["Checkers", "Draughts"]
    assert all(isinstance(game, GameStats) for game in profile.games.values())


def test_profile_fetches_each_game_page_once(monkeypatch) -> None:
    from bs4 import BeautifulSoup

    client = FlyOrDieClient()
    requests = []
    page = BeautifulSoup("<html></html>", "html.parser")
    monkeypatch.setattr(client, "_get_soup", lambda url: requests.append(url) or page)
    monkeypatch.setattr(client, "_parse_profile", lambda name, _: PlayerProfile(name))
    monkeypatch.setattr(client, "_game_slugs", lambda _: ["Chess"])
    monkeypatch.setattr(client, "_parse_game", lambda slug, _: GameStats(slug, rating=100))

    client.profile("Mike05")

    assert requests == ["https://games.flyordie.com/players/Mike05", "https://games.flyordie.com/players/Mike05/Chess"]

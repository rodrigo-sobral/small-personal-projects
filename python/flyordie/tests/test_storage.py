from flyordie.domain import GameStats, PlayerProfile
from flyordie.storage import PlayerStore


def test_store_round_trips_merged_profiles_and_derived_stats(tmp_path) -> None:
    store = PlayerStore(tmp_path / "players.yaml")
    profile = PlayerProfile(
        "Ana",
        country="PT",
        games={"chess": GameStats("chess", rating=1200, matches=10, wins=6, draws=2, losses=2)},
    )

    store.merge(profile)
    loaded = store.load()

    assert loaded["Ana"] == profile
    assert loaded["Ana"].games["chess"].as_dict()["wins_percent"] == 60.0


def test_store_merge_is_case_insensitive(tmp_path) -> None:
    store = PlayerStore(tmp_path / "players.yaml")
    store.merge(PlayerProfile("Ana", games={"chess": GameStats("chess", rating=1000)}))
    store.merge(PlayerProfile("ana", games={"chess": GameStats("chess", rating=1100)}))

    loaded = store.load()

    assert list(loaded) == ["Ana"]
    assert loaded["Ana"].games["chess"].rating == 1100

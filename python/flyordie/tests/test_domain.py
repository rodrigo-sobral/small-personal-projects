from datetime import date

from flyordie.domain import expected_score, project


def test_expected_score_favours_higher_rated_player() -> None:
    assert expected_score(1800, 2000) < 0.5
    assert expected_score(2000, 1800) > 0.5
    assert round(expected_score(1800, 2000) + expected_score(2000, 1800), 8) == 1


def test_projection_is_deterministic_with_injected_date() -> None:
    result = project(1500, 1700, date(2025, 1, 1))
    assert result.win_rating > 1500 > result.loss_rating
    assert result.zero_date > date(2025, 1, 1)

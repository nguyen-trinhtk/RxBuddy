import pytest

from app import rxnorm

APPROX = {"approximateGroup": {"candidate": [{"rxcui": "224920", "name": "Synthroid"}]}}
RELATED = {"relatedGroup": {"conceptGroup": [
    {"tty": "IN", "conceptProperties": [{"rxcui": "10582", "name": "levothyroxine"}]}]}}
NO_MATCH = {"approximateGroup": {"inputTerm": None}}


@pytest.fixture
def fake_api(tmp_path, monkeypatch):
    monkeypatch.setattr(rxnorm, "CACHE_PATH", tmp_path / "rxnorm.json")
    calls = []
    responses = {}

    def fake_get(path, params=None):
        calls.append(path)
        return responses[path]

    monkeypatch.setattr(rxnorm, "_get", fake_get)
    return responses, calls


def test_brand_name_resolves_to_ingredient(fake_api):
    responses, _ = fake_api
    responses["/approximateTerm.json"] = APPROX
    responses["/rxcui/224920/related.json"] = RELATED
    assert rxnorm.normalize("Synthroid 50mcg") == {"rxcui": "224920", "ingredient": "levothyroxine"}


def test_second_lookup_uses_disk_cache(fake_api):
    responses, calls = fake_api
    responses["/approximateTerm.json"] = APPROX
    responses["/rxcui/224920/related.json"] = RELATED
    rxnorm.normalize("Synthroid 50mcg")
    calls.clear()
    assert rxnorm.normalize("  synthroid 50MCG ")["ingredient"] == "levothyroxine"
    assert calls == []
    assert rxnorm.CACHE_PATH.exists()


def test_unknown_name_returns_none_and_is_cached(fake_api):
    responses, calls = fake_api
    responses["/approximateTerm.json"] = NO_MATCH
    assert rxnorm.normalize("xqzzvb") is None
    calls.clear()
    assert rxnorm.normalize("xqzzvb") is None
    assert calls == []


def test_combination_product_joins_ingredients(fake_api):
    responses, _ = fake_api
    responses["/approximateTerm.json"] = {"approximateGroup": {"candidate": [{"rxcui": "1"}]}}
    responses["/rxcui/1/related.json"] = {"relatedGroup": {"conceptGroup": [{"tty": "IN", "conceptProperties": [
        {"rxcui": "2", "name": "magnesium hydroxide"}, {"rxcui": "3", "name": "Calcium Carbonate"}]}]}}
    assert rxnorm.normalize("Rolaids")["ingredient"] == "calcium carbonate / magnesium hydroxide"


def test_empty_name_returns_none_without_network(fake_api):
    _, calls = fake_api
    assert rxnorm.normalize("   ") is None
    assert calls == []

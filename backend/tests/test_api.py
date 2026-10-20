import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.main import app
from app.schemas import Clash

client = TestClient(app)

MED = {"raw_name": "Synthroid 50mcg", "ingredient": "levothyroxine", "strength": "50 mcg",
       "frequency_per_day": 1, "with_food": "empty_stomach", "confidence": 0.9}


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_parse_stub():
    r = client.post("/parse", files={"image": ("label.jpg", b"\xff\xd8fake", "image/jpeg")})
    assert r.status_code == 200
    assert r.json()["meds"][0]["ingredient"] == "levothyroxine"


def test_parse_rejects_empty_image():
    r = client.post("/parse", files={"image": ("label.jpg", b"", "image/jpeg")})
    assert r.status_code == 400


def test_analyze_stub():
    r = client.post("/analyze", json={"meds": [MED], "wake": "07:00", "sleep": "23:00"})
    assert r.status_code == 200
    body = r.json()
    assert {c["type"] for c in body["clashes"]} == {"timing_resolvable", "pharmacist_required"}
    assert all(c["source"]["quote"] for c in body["clashes"])


@pytest.mark.parametrize("payload", [
    {"meds": [], "wake": "07:00", "sleep": "23:00"},
    {"meds": [MED], "wake": "7am", "sleep": "23:00"},
])
def test_analyze_rejects_bad_input(payload):
    assert client.post("/analyze", json=payload).status_code == 422


def _clash(**kw):
    base = {"drugs": ["a", "b"], "type": "timing_resolvable", "gap_hours": 4, "summary": "s",
            "source": {"setid": "x", "section": "Drug Interactions", "quote": "4 hours apart"}}
    return Clash.model_validate({**base, **kw})


def test_rule1_gap_requires_quote():
    with pytest.raises(ValidationError):
        _clash(source={"setid": "x", "section": "s", "quote": " "})


def test_rule1_no_gap_on_pharmacist_required():
    with pytest.raises(ValidationError):
        _clash(type="pharmacist_required")

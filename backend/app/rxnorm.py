"""Drug name → RxCUI → ingredient via RxNav, with an on-disk JSON cache."""

import json
from pathlib import Path

import httpx

BASE = "https://rxnav.nlm.nih.gov/REST"
CACHE_PATH = Path(__file__).resolve().parent.parent / "data" / "cache" / "rxnorm.json"


def _get(path: str, params: dict | None = None) -> dict:
    r = httpx.get(BASE + path, params=params, timeout=15)
    r.raise_for_status()
    return r.json()


def _load_cache() -> dict:
    return json.loads(CACHE_PATH.read_text()) if CACHE_PATH.exists() else {}


def _lookup(name: str) -> dict | None:
    candidates = _get("/approximateTerm.json", {"term": name, "maxEntries": 1})["approximateGroup"].get("candidate")
    if not candidates:
        return None
    rxcui = candidates[0]["rxcui"]
    groups = _get(f"/rxcui/{rxcui}/related.json", {"tty": "IN"})["relatedGroup"].get("conceptGroup") or []
    names = sorted({p["name"].lower() for g in groups for p in g.get("conceptProperties") or []})
    if not names:
        return None
    return {"rxcui": rxcui, "ingredient": " / ".join(names)}


def normalize(name: str) -> dict | None:
    """Return {"rxcui", "ingredient"} or None if RxNorm has no match. Network errors propagate."""
    key = " ".join(name.lower().split())
    if not key:
        return None
    cache = _load_cache()
    if key not in cache:
        cache[key] = _lookup(key)
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        CACHE_PATH.write_text(json.dumps(cache, indent=1, sort_keys=True))
    return cache[key]

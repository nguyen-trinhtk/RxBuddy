"""Block B checkpoint. Needs the built index: python -m scripts.fetch_labels && python -m scripts.build_index"""

import pytest

from app import rag

pytestmark = pytest.mark.skipif(not (rag.CHROMA_PATH / "chroma.sqlite3").exists(), reason="index not built")


def test_levothyroxine_calcium_paragraph_in_top3():
    hits = rag.query("levothyroxine", "calcium")
    assert len(hits) == 3
    assert any("calcium carbonate" in h["text"] and "4 hours" in h["text"] for h in hits)
    assert all(h["ingredient"] == "levothyroxine" and h["setid"] and h["section"] for h in hits)


def test_unindexed_drug_returns_nothing():
    assert rag.query("notadrug", "calcium") == []

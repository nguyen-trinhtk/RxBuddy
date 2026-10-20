"""Vector search over DailyMed label chunks (Chroma + bge-small)."""

from functools import cache
from pathlib import Path

CHROMA_PATH = Path(__file__).resolve().parent.parent / "data" / "chroma"
COLLECTION = "labels"
MODEL = "BAAI/bge-small-en-v1.5"
QUERY_PREFIX = "Represent this sentence for searching relevant passages: "  # bge convention for queries


@cache
def _model():
    from sentence_transformers import SentenceTransformer
    return SentenceTransformer(MODEL)


def embed(texts: list[str]) -> list[list[float]]:
    return _model().encode(texts, normalize_embeddings=True).tolist()


@cache
def collection():
    import chromadb
    client = chromadb.PersistentClient(path=str(CHROMA_PATH))
    return client.get_or_create_collection(COLLECTION, metadata={"hnsw:space": "cosine"})


def query(drug: str, other: str, k: int = 3) -> list[dict]:
    """Top-k chunks from `drug`'s label about taking it with `other`.

    Returns [{"text", "ingredient", "setid", "section", "distance"}]; empty if the drug isn't indexed.
    """
    res = collection().query(
        query_embeddings=embed([f"{QUERY_PREFIX}{drug} taken with {other}: interaction, absorption, hours apart"]),
        n_results=k,
        where={"ingredient": drug},
    )
    return [{"text": doc, **meta, "distance": dist}
            for doc, meta, dist in zip(res["documents"][0], res["metadatas"][0], res["distances"][0])]

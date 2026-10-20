"""data/labels/*.json → chunk by section → embed (bge-small) → data/chroma/.

Run from backend/: .venv/bin/python -m scripts.build_index
"""

import json
from pathlib import Path

from app import rag

LABELS = Path(__file__).resolve().parent.parent / "data" / "labels"
MAX_WORDS = 375  # ≈ 500 tokens at ~0.75 words/token; packed paragraphs land in the 300–500 token range


def chunk_section(text: str) -> list[str]:
    """Pack paragraphs into chunks of at most MAX_WORDS words; split paragraphs that are longer."""
    pieces = []
    for para in text.splitlines():
        words = para.split()
        pieces += [" ".join(words[i:i + MAX_WORDS]) for i in range(0, len(words), MAX_WORDS)]
    chunks, current = [], []
    for piece in pieces:
        if current and len(" ".join(current + [piece]).split()) > MAX_WORDS:
            chunks.append("\n".join(current))
            current = []
        current.append(piece)
    if current:
        chunks.append("\n".join(current))
    return chunks


def main() -> None:
    ids, docs, metas = [], [], []
    for path in sorted(LABELS.glob("*.json")):
        label = json.loads(path.read_text())
        for section, text in label["sections"].items():
            for i, chunk in enumerate(chunk_section(text)):
                ids.append(f"{label['ingredient']}|{section}|{i}")
                docs.append(f"{section}: {chunk}")
                metas.append({"ingredient": label["ingredient"], "setid": label["setid"], "section": section})
    if not ids:
        raise SystemExit(f"no labels in {LABELS}; run scripts.fetch_labels first")

    import chromadb
    client = chromadb.PersistentClient(path=str(rag.CHROMA_PATH))
    if rag.COLLECTION in [c.name for c in client.list_collections()]:
        client.delete_collection(rag.COLLECTION)
    col = rag.collection()
    col.add(ids=ids, documents=docs, metadatas=metas, embeddings=rag.embed(docs))
    print(f"indexed {len(ids)} chunks from {len(set(m['ingredient'] for m in metas))} labels → {rag.CHROMA_PATH}")


if __name__ == "__main__":
    main()

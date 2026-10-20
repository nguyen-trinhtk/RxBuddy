"""DailyMed → data/labels/{ingredient}.json (Drug Interactions, Dosage and Administration, Warnings).

Run from backend/: .venv/bin/python -m scripts.fetch_labels
"""

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import httpx

DATA = Path(__file__).resolve().parent.parent / "data"
DAILYMED = "https://dailymed.nlm.nih.gov/dailymed/services/v2"
NS = "{urn:hl7-org:v3}"

# LOINC section codes → section name. Rx labels use "Warnings and Precautions"; OTC/older use "Warnings".
SECTIONS = {
    "34073-7": "Drug Interactions",
    "34068-7": "Dosage and Administration",
    "43685-7": "Warnings",
    "34071-1": "Warnings",
}
BLOCK_TAGS = {"paragraph", "title", "item", "tr", "section"}


NON_ORAL = ("OTIC", "OPHTHALMIC", "OINTMENT", "CREAM", "LOTION", "TOPICAL", "INJECTION", "SPRAY", "PATCH")


def pick_setid(ingredient: str, results: list[dict]) -> str | None:
    """First oral SPL whose product is the ingredient alone (no combos like 'A, B' or 'A AND B').

    Prefers tablets/capsules (full Rx labels), then any other oral form.
    """
    name = ingredient.upper()
    matches = []
    for r in results:
        title = r["title"]
        # Ingredient list is in parens if present, e.g. "BRAND (A, B) TABLET [labeler]"; else the title's start.
        head = title.split("(", 1)[1].split(")", 1)[0] if "(" in title else title.split(" [")[0].split(",")[0]
        if (head.startswith(name) and "," not in head and " AND " not in head
                and not any(w in title for w in NON_ORAL)):
            matches.append(r)
    solid = [r for r in matches if "TABLET" in r["title"] or "CAPSULE" in r["title"]]
    return (solid or matches or [{"setid": None}])[0]["setid"]


def _text(el: ET.Element) -> str:
    parts = [el.text or ""]
    for child in el:
        tag = child.tag.removeprefix(NS)
        parts.append(_text(child))
        parts.append("\n" if tag in BLOCK_TAGS else " " if tag == "td" else "")
        parts.append(child.tail or "")
    return "".join(parts)


def extract_sections(xml: bytes) -> dict[str, str]:
    out: dict[str, list[str]] = {}

    def walk(el: ET.Element) -> None:
        for child in el:
            code = child.find(NS + "code") if child.tag == NS + "section" else None
            name = SECTIONS.get(code.get("code")) if code is not None else None
            if name:  # take the whole subtree; subsections often reuse the parent's code
                lines = (" ".join(line.split()) for line in _text(child).splitlines())
                out.setdefault(name, []).append("\n".join(line for line in lines if line))
            else:
                walk(child)

    walk(ET.fromstring(xml))
    return {name: "\n".join(texts) for name, texts in out.items()}


def fetch(ingredient: str, client: httpx.Client) -> dict | None:
    r = client.get(f"{DAILYMED}/spls.json", params={"drug_name": ingredient, "pagesize": 100})
    r.raise_for_status()
    results = r.json()["data"]
    setid = pick_setid(ingredient, results)
    if not setid:
        return None
    xml = client.get(f"{DAILYMED}/spls/{setid}.xml")
    xml.raise_for_status()
    title = next(x["title"] for x in results if x["setid"] == setid)
    return {"ingredient": ingredient, "setid": setid, "title": title, "sections": extract_sections(xml.content)}


def main() -> None:
    drugs = [line.strip() for line in (DATA / "drugs.txt").read_text().splitlines()
             if line.strip() and not line.startswith("#")]
    out_dir = DATA / "labels"
    out_dir.mkdir(parents=True, exist_ok=True)
    failed = []
    with httpx.Client(timeout=60, follow_redirects=True) as client:
        for drug in drugs:
            label = fetch(drug, client)
            if not label or not label["sections"]:
                failed.append(drug)
                print(f"MISS  {drug}")
                continue
            (out_dir / f"{drug}.json").write_text(json.dumps(label, indent=1))
            print(f"ok    {drug:22} {label['setid']}  {sorted(label['sections'])}  {label['title'][:60]}")
    print(f"\n{len(drugs) - len(failed)}/{len(drugs)} labels written to {out_dir}")
    if failed:
        print("missing:", ", ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()

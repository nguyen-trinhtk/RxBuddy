from scripts.build_index import chunk_section
from scripts.fetch_labels import extract_sections, pick_setid

SPL = """<?xml version="1.0"?>
<document xmlns="urn:hl7-org:v3"><component><structuredBody>
  <component><section><code code="34068-7"/><title>2 DOSAGE AND ADMINISTRATION</title>
    <text><paragraph>Take on an empty stomach.</paragraph></text></section></component>
  <component><section><code code="43685-7"/><title>5 WARNINGS AND PRECAUTIONS</title>
    <component><section><code code="42229-5"/><title>5.1 Cardiac</title>
      <text><paragraph>Monitor heart rate.</paragraph></text></section></component></section></component>
  <component><section><code code="34073-7"/><title>7 DRUG INTERACTIONS</title>
    <text><paragraph>Administer at least <content>4 hours</content> apart from calcium carbonate.</paragraph>
      <table><tr><td>Iron</td><td>Binds</td></tr></table></text></section></component>
  <component><section><code code="34084-4"/><title>6 ADVERSE REACTIONS</title>
    <text><paragraph>Hair loss.</paragraph></text></section></component>
</structuredBody></component></document>"""


def test_extracts_the_three_sections_only():
    sections = extract_sections(SPL.encode())
    assert set(sections) == {"Dosage and Administration", "Warnings", "Drug Interactions"}
    assert "Hair loss" not in " ".join(sections.values())


def test_nested_subsections_and_inline_markup_are_kept():
    sections = extract_sections(SPL.encode())
    assert "Monitor heart rate." in sections["Warnings"]
    assert "Administer at least 4 hours apart from calcium carbonate." in sections["Drug Interactions"]
    assert "Iron" in sections["Drug Interactions"]


def test_pick_setid_prefers_single_ingredient_product():
    results = [
        {"setid": "combo", "title": "ROLAIDS (CALCIUM CARBONATE, MAGNESIUM HYDROXIDE) TABLET [X]"},
        {"setid": "homeopathic", "title": "LEG CRAMPS (OYSTER SHELL CALCIUM CARBONATE, CRUDE) [Y]"},
        {"setid": "plain", "title": "ANTACID CHEWS (CALCIUM CARBONATE) LOZENGE [Z]"},
    ]
    assert pick_setid("calcium carbonate", results) == "plain"


def test_pick_setid_accepts_generic_title_without_parens():
    results = [{"setid": "levo", "title": "LEVOTHYROXINE SODIUM TABLET [ALVOGEN, INC.]"}]
    assert pick_setid("levothyroxine", results) == "levo"


def test_pick_setid_none_when_nothing_matches():
    assert pick_setid("warfarin", [{"setid": "x", "title": "IBUPROFEN TABLET [X]"}]) is None


def test_chunks_respect_size_and_keep_paragraphs():
    para = " ".join(["word"] * 200)
    text = "\n".join([para, para, "short tail"])
    chunks = chunk_section(text)
    assert all(len(c.split()) <= 375 for c in chunks)
    assert len(chunks) == 2
    assert chunks[-1].endswith("short tail")


def test_overlong_paragraph_is_split():
    chunks = chunk_section(" ".join(["w"] * 1000))
    assert len(chunks) == 3
    assert sum(len(c.split()) for c in chunks) == 1000


def test_empty_section_has_no_chunks():
    assert chunk_section("  \n ") == []


def test_pick_setid_prefers_oral_tablet_and_skips_topicals():
    results = [
        {"setid": "otic", "title": "CIPROFLOXACIN OTIC (CIPROFLOXACIN) SOLUTION/ DROPS [X]"},
        {"setid": "tab", "title": "CIPROFLOXACIN TABLET, FILM COATED [Y]"},
    ]
    assert pick_setid("ciprofloxacin", results) == "tab"
    ointment = [{"setid": "oint", "title": "CLARAVIE (ALUMINUM HYDROXIDE GEL) OINTMENT [Z]"}]
    assert pick_setid("aluminum hydroxide", ointment) is None


def test_subsection_reusing_parent_code_is_not_duplicated():
    spl = """<document xmlns="urn:hl7-org:v3"><component><structuredBody><component><section>
      <code code="34073-7"/><title>7 DRUG INTERACTIONS</title>
      <component><section><code code="34073-7"/><title>7.1 Absorption</title>
        <text><paragraph>4 hours apart.</paragraph></text></section></component>
    </section></component></structuredBody></component></document>"""
    assert extract_sections(spl.encode())["Drug Interactions"].count("4 hours apart.") == 1

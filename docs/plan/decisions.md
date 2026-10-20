# RxBuddy — design decisions

Why the MVP is built the way it is, and what we'd test next. Companion to [README.md](README.md).

---

## 1. No server database (no MongoDB)

Nothing in the MVP needs one: user data lives on the phone (SwiftData), vectors in Chroma (local file), labels, the RxNorm cache and the clash table in JSON files. Accounts/sync are cut. Revisit only when v2 adds accounts.

The precomputed clash table (§7) is 435 rows (~30 drugs → all pairs), written once by a script and only ever read by key. A JSON file loaded into a dict at startup gives microsecond lookups, is diffable in git, and needs no server. MongoDB would add a process to run, a driver, and connection handling for no gain at this size. If the table outgrows memory (thousands of drugs), SQLite is the next step, still serverless.

## 2. Models

**Parse (OCR text → JSON): no LLM in the MVP.** Prescription labels are semi-standard, so rules cover most of it: RxNorm fuzzy match per OCR line for the drug, regex for strength, a phrase map for frequency and food. Free, instant, offline apart from cached RxNorm calls, and unit-testable. Rules break on noise lines, OCR typos, split or unusual instructions; a missing field lowers `confidence` and the user fixes it on the review screen. If the parse eval is poor, add Haiku 5.5 as a fallback only for scans where rules leave fields empty (v2 item 1).

**Classify (pairs → clash): open model on a free Kaggle GPU.** Qwen3-14B, 4-bit AWQ, in vLLM on Kaggle's 2× T4 (16 GB each, ~30 GPU-hours/week free). It runs once, offline, so latency barely matters; it costs nothing; and no label text or prompts leave our control. Accuracy is the risk: a 14B model is weaker than Claude Opus. The gold-pair eval decides; if dangerous misses aren't 0, try MedGemma 27B (4-bit, both T4s) or use Claude on just the pairs the open model is unsure about.

**Claude as a baseline:** run Claude Opus 5.5 on the 30 gold pairs only (~$1.50) to give the open model a number to beat. Claude Pro doesn't cover API calls; this needs prepaid API credits from console.anthropic.com. Optional.

**Why the notebook only generates:** prompt building (retrieval) and verification (quote check, vote, §5 rules) stay in `classify.py` in the repo, unit-tested. Kaggle just turns `prompts.jsonl` into `results.jsonl`. The GPU environment holds no project logic, and swapping models is a notebook-cell change.

**Settings:** the backend no longer calls any LLM, so `RXBUDDY_MODEL` goes away; the model id lives in the notebook.

## 3. Offline and medical models

Reading a label is OCR + structuring, not medical reasoning, so a medical model doesn't help with parsing. **Chosen for the MVP: Apple Vision OCR on-device** (fastest, free, private, no photo upload); the models below are v2 comparisons.

| Model | Input | Fit |
|---|---|---|
| Qwen3-VL (open, local via Ollama/MLX) | text + images | Best offline candidate for **parse**. Private (photos never leave the machine), free, slower, likely weaker on blur/glare. |
| MedGemma 4B / 27B (Google, open) | text + images | Tuned for medical Q&A and imaging (X-ray, derm). Candidate for **classify**, not parse. |
| LLaVA-Med (Microsoft) | text + images | Biomedical figures/scans. Not labels. |
| Meditron, BioMistral, OpenBioLLM | text | Medical Q&A. |

## 4. Interaction databases

| Source | Access | Notes |
|---|---|---|
| Lexicomp, Micromedex, First Databank, Medi-Span | Paid | What pharmacies use; include management and spacing. |
| DDInter | Free (academic) | ~240k pairs, severity + short management notes. |
| DrugBank | Free (non-commercial) | Free-text interaction descriptions. |
| ONC high-priority DDI list | Free | Short, curated list of the most dangerous pairs. |
| NLM RxNav interaction API | — | Retired Jan 2024. |

Free databases give *whether* and *how bad*, rarely *how many hours apart*. Spacing lives in the FDA labels, hence RAG.

**Planned use (v2):** DDInter as a safety net. If it rates a pair *major* or *contraindicated*, force `pharmacist_required` in code regardless of the LLM. Labels + LLM handle gap hours and the quote.

**Why not train a model on it:** if the pair is in the table, a lookup is exact and citable; a model only adds predictions for unlisted pairs, which is where guessing is least acceptable (§5 rule 2 says escalate). It also can't quote a source (§5 rule 1), its labels are severity not hours, and DDInter/DrugBank licences restrict use. Training makes sense later for parsing (fine-tune a small VLM if the eval shows systematic misreads) or for cost (distil the classifier from verified LLM outputs).

## 5. Where ML is used

| Stage | Model | Job |
|---|---|---|
| OCR (phone) | Apple Vision | photo → text |
| Parse | none (rules + RxNorm) | text → meds JSON |
| Retrieve (offline) | bge-small embeddings | find the right paragraph in a long label |
| Classify (offline) | Qwen3-14B AWQ on Kaggle (vLLM) | read the paragraph → `{type, gap_hours, quote}` |
| Analyze | none (lookup) | clash table → clashes |
| Schedule | none (rules) | place doses |

## 6. Why RAG (vs. the LLM answering from memory)

| | LLM only | LLM + RAG |
|---|---|---|
| Source | none, or an invented quote | real label paragraph |
| Checkable | no | yes: code checks the quote is a verbatim substring of the retrieved text |
| Exact numbers | good for famous pairs, shaky elsewhere | read off the label |
| Freshness | frozen at training cutoff | re-fetch labels |
| Unknown pairs | answers anyway | nothing retrieved → escalate |

For famous gold-set pairs, memory alone will often get the *type* right. RAG's clearest wins are the citation and the ability to verify it in code.

**Quote check (Block E):** in `classify.py`, if the returned quote is not a verbatim substring of the retrieved chunks, drop `gap_hours` and escalate to `pharmacist_required`. This enforces §5 rule 1 in code.

**Alternative worth measuring:** with only ~30 drugs, stuffing both drugs' full label sections into the prompt (no retrieval) is feasible. Simpler, possibly as accurate; costs more per pair and makes the quote less pinpointed (warfarin's interaction section is huge).

## 7. Latency

Most of a model call's latency is generating tokens, not the network (~0.1–0.3 s round trip). Datacenter GPUs generate far faster than a laptop, so a local Qwen3-VL 8B (~10–30 s per photo) loses to cloud Claude (~3–6 s with a photo). Self-hosting on a rented GPU is fast per token but not faster than Claude for one user, and adds hourly cost, cold starts and ops.

What actually cuts latency, in order:

1. **Precompute the clash check.** The index only covers ~30 drugs → 435 pairs. Classify them all offline into `clash_table.json`; `/analyze` becomes a dict lookup (milliseconds). A pair not in the table → `pharmacist_required` (§5 rule 2), never a live guess.
2. **OCR on the phone.** Apple Vision takes ~0.1–0.3 s and removes the photo upload.
3. **No LLM on the live path.** Parse is rules + RxNorm (cached); classify runs once, offline, on Kaggle.

Expected end-to-end: OCR ~0.3 s + parse well under 1 s (RxNorm cache hits; first-time names add a network call) + analyze ~0 s. `parse_eval.py` logs latency per photo so this is measured, not assumed.

Trade-off: Apple Vision struggles with curved bottles and glare. If the parse eval shows OCR misses, add a VLM-on-image fallback for low-confidence scans (v2 roadmap item 3).

## 8. Experiments to report (README results table)

Run each on `clash_eval.py` / `parse_eval.py` and compare: type accuracy, gap-hours exact match, dangerous misses, quote-verified rate, cost, latency.

1. **Classify:** RAG vs. no context (memory only) vs. full label sections in prompt.
2. **Classify:** Qwen3-14B AWQ vs. MedGemma 27B vs. Claude Opus 5.5 (gold pairs).
3. **Classify:** with vs. without the DDInter override.
4. **Parse:** rules (MVP) vs. rules + Haiku fallback vs. Claude on the raw image vs. local Qwen3-VL.
5. **Table build:** each optimization in §9 on/off → pairs per minute, total GPU time, and accuracy (quantization and voting can change it).

## 9. Optimizing the offline table build

Goal: build all 435 pairs fast on free hardware without losing accuracy. Each technique is measured on/off (pairs/min, GPU minutes, gold-pair accuracy) and reported.

| Technique | What it does | Why here |
|---|---|---|
| **4-bit quantization (AWQ)** | Shrinks a 14B model from ~28 GB to ~9 GB | Fits on a 16 GB T4; check the accuracy cost on the gold pairs |
| **Batched inference (vLLM continuous batching)** | Runs many prompts at once instead of one by one | 435 independent prompts are the ideal case; the biggest speed-up |
| **Prefix caching** | Reuses the computed shared prompt prefix across requests | Every prompt starts with the same instructions; put them first, pair-specific chunks last |
| **Tensor parallelism (2× T4)** | Splits the model across both free GPUs | More memory for the batch, higher throughput |
| **JSON-schema guided decoding** | The model can only emit valid JSON in our schema | No parse failures, no retries |
| **Self-consistency voting (3 samples)** | Majority vote; disagreement → `pharmacist_required` | Turns model uncertainty into the safe default (§5 rule 2); costs 3× compute, which is free here |
| **Retrieval cache** | Retrieve each (drug, other) once, reuse across samples | Keeps the export step fast |

Note: T4s don't support bf16 or FlashAttention 2; run vLLM in fp16 (it falls back automatically). Kaggle sessions cap at 12 h, so write `results.jsonl` incrementally and resume by skipping finished pairs.

"""FastAPI routes. Block A: /parse and /analyze return validated fixtures."""

import json
from pathlib import Path

from fastapi import FastAPI, HTTPException, UploadFile

from .schemas import AnalyzeRequest, AnalyzeResponse, ParseResponse

FIXTURES = Path(__file__).parent / "fixtures"

app = FastAPI(title="RxBuddy")


def _fixture(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text())


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/parse", response_model=ParseResponse)
async def parse(image: UploadFile) -> ParseResponse:
    if not (await image.read()):
        raise HTTPException(400, "empty image")
    return ParseResponse.model_validate(_fixture("parse.json"))  # stub until Block C


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(req: AnalyzeRequest) -> AnalyzeResponse:
    return AnalyzeResponse.model_validate(_fixture("analyze.json"))  # stub until Block E

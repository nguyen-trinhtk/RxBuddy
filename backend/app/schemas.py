"""Pydantic models = the API contract (docs/plan/README.md §4)."""

from typing import Literal

from pydantic import BaseModel, Field, model_validator

HHMM = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")


class Medication(BaseModel):
    raw_name: str
    rxcui: str | None = None
    ingredient: str
    strength: str
    frequency_per_day: int = Field(ge=1, le=6)
    with_food: Literal["empty_stomach", "with_food", "any"] = "any"
    confidence: float = Field(ge=0, le=1)


class Source(BaseModel):
    setid: str
    section: str
    quote: str


class Clash(BaseModel):
    drugs: list[str] = Field(min_length=2, max_length=2)
    type: Literal["timing_resolvable", "pharmacist_required"]
    gap_hours: int | None = Field(default=None, gt=0)
    summary: str
    source: Source

    @model_validator(mode="after")
    def gap_needs_quote(self):
        # Hard rule 1: no gap without a quote, and only for timing clashes.
        if self.gap_hours is not None:
            if self.type != "timing_resolvable":
                raise ValueError("gap_hours is only allowed for timing_resolvable clashes")
            if not self.source.quote.strip():
                raise ValueError("gap_hours requires a source quote")
        return self


class DoseEvent(BaseModel):
    ingredient: str
    time: str = HHMM
    note: str | None = None


class ParseResponse(BaseModel):
    meds: list[Medication]
    warnings: list[str] = []


class AnalyzeRequest(BaseModel):
    meds: list[Medication] = Field(min_length=1)
    wake: str = HHMM
    sleep: str = HHMM


class AnalyzeResponse(BaseModel):
    clashes: list[Clash]
    schedule: list[DoseEvent]

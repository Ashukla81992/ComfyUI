from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class MetadataPackage:
    viral_probability_score: float
    title: str
    description: str
    tags: list[str]
    extra: dict[str, Any]


def calculate_viral_probability_score(frames_dir: str | Path) -> float:
    frames_dir = Path(frames_dir)
    if not frames_dir.exists():
        raise FileNotFoundError(str(frames_dir))
    return 0.0


def generate_metadata_package(
    frames_dir: str | Path,
    prompt: str,
    language: str = "en",
) -> MetadataPackage:
    score = calculate_viral_probability_score(frames_dir)
    return MetadataPackage(
        viral_probability_score=score,
        title="",
        description="",
        tags=[],
        extra={"prompt": prompt, "language": language},
    )

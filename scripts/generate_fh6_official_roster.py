#!/usr/bin/env python3
"""Generate the bundled FH6 identity roster from an official Forza HTML page."""

from __future__ import annotations

import argparse
import hashlib
import html.parser
import json
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


EXPECTED_HEADERS = [
    "Make",
    "Car Name",
    "Car Type",
    "Car Class",
    "Country",
    "Collection",
    "Add-Ons",
]
EXPECTED_ROW_COUNT = 627
EXPECTED_UPDATED_TEXT = "Updated 14 July 2026"
SOURCE_URL = "https://forza.net/fh6cars"
REVISION = "2026.07.14.official"


class FirstTableParser(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.in_table = False
        self.in_cell = False
        self.finished = False
        self.current_cell: list[str] = []
        self.current_row: list[str] | None = None
        self.rows: list[list[str]] = []

    def handle_starttag(
        self,
        tag: str,
        attrs: list[tuple[str, str | None]],
    ) -> None:
        del attrs
        if tag == "table" and not self.in_table and not self.finished:
            self.in_table = True
        elif self.in_table and tag == "tr":
            self.current_row = []
        elif self.in_table and tag in {"td", "th"}:
            self.in_cell = True
            self.current_cell = []

    def handle_data(self, data: str) -> None:
        if self.in_cell:
            self.current_cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        if self.in_table and tag in {"td", "th"} and self.in_cell:
            assert self.current_row is not None
            value = "".join(self.current_cell)
            self.current_row.append(value.strip())
            self.in_cell = False
        elif self.in_table and tag == "tr" and self.current_row:
            self.rows.append(self.current_row)
            self.current_row = None
        elif self.in_table and tag == "table":
            self.in_table = False
            self.finished = True


@dataclass(frozen=True)
class RosterEntry:
    identifier: str
    year: int
    make: str
    model: str
    official_designation: str
    performance_index: int
    performance_class: str

    def as_json(self) -> dict[str, object]:
        return {
            "id": self.identifier,
            "year": self.year,
            "make": self.make,
            "model": self.model,
            "officialDesignation": self.official_designation,
            "performanceIndex": self.performance_index,
            "performanceClass": self.performance_class,
        }


def stable_slug(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    ascii_value = decomposed.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"(^-|-$)", "", re.sub(r"[^a-z0-9]+", "-", ascii_value.lower()))


def parse_entry(row: list[str]) -> RosterEntry:
    if len(row) != len(EXPECTED_HEADERS):
        raise ValueError(f"Expected 7 cells, found {len(row)}: {row!r}")

    make, designation, _, class_value, _, _, _ = row
    identity_match = re.fullmatch(r"(\d{4}) (.+)", designation)
    if identity_match is None:
        raise ValueError(f"Invalid official designation: {designation!r}")

    year = int(identity_match.group(1))
    expected_prefix = f"{year} {make} "
    if not designation.startswith(expected_prefix):
        raise ValueError(
            f"Designation does not preserve make {make!r}: {designation!r}"
        )
    model = designation[len(expected_prefix) :]
    if not model:
        raise ValueError(f"Missing model in designation: {designation!r}")

    class_match = re.fullmatch(r"(\d{3}) (D|C|B|A|S1|S2|R|X)", class_value)
    if class_match is None:
        raise ValueError(f"Invalid official class value: {class_value!r}")
    performance_index = int(class_match.group(1))
    performance_class = class_match.group(2)

    identifier = f"fh6-{stable_slug(designation)}"
    return RosterEntry(
        identifier=identifier,
        year=year,
        make=make,
        model=model,
        official_designation=designation,
        performance_index=performance_index,
        performance_class=performance_class,
    )


def generate(source: Path) -> dict[str, object]:
    source_data = source.read_bytes()
    source_text = source_data.decode("utf-8")
    if EXPECTED_UPDATED_TEXT not in source_text:
        raise ValueError(f"Missing source marker: {EXPECTED_UPDATED_TEXT}")

    parser = FirstTableParser()
    parser.feed(source_text)
    if not parser.rows or parser.rows[0] != EXPECTED_HEADERS:
        raise ValueError(
            f"Unexpected table headers: {parser.rows[0] if parser.rows else None!r}"
        )

    entries = [parse_entry(row) for row in parser.rows[1:]]
    if len(entries) != EXPECTED_ROW_COUNT:
        raise ValueError(
            f"Expected {EXPECTED_ROW_COUNT} rows, found {len(entries)}"
        )
    identifiers = [entry.identifier for entry in entries]
    if len(set(identifiers)) != len(identifiers):
        duplicates = sorted(
            identifier
            for identifier in set(identifiers)
            if identifiers.count(identifier) > 1
        )
        raise ValueError(f"Duplicate stable IDs: {duplicates}")

    return {
        "schemaVersion": 1,
        "revision": REVISION,
        "sourceURL": SOURCE_URL,
        "sourceUpdatedAt": datetime(
            2026,
            7,
            14,
            tzinfo=timezone.utc,
        ).isoformat().replace("+00:00", "Z"),
        "sourceSHA256": hashlib.sha256(source_data).hexdigest(),
        "entries": [entry.as_json() for entry in entries],
    }


def main() -> None:
    argument_parser = argparse.ArgumentParser()
    argument_parser.add_argument("source_html", type=Path)
    argument_parser.add_argument("output_json", type=Path)
    arguments = argument_parser.parse_args()

    payload = generate(arguments.source_html)
    arguments.output_json.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
            sort_keys=False,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

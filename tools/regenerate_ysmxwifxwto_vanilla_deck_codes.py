from __future__ import annotations

import base64
import csv
import os
import re
from pathlib import Path

from extract_ysmxwifxwto_division_ids import extract_serializer_ids


ROOT = Path(__file__).resolve().parents[1]
BASE_DECK_DIR = Path(
    os.environ.get(
        "WARNO_BASE_DECK_DIR",
        str(ROOT / "source-data" / "base-decks" / "GameData" / "Generated" / "Gameplay" / "Decks"),
    )
)
EXISTING_CSV = ROOT / "data" / "ysmxwifxwto_vanilla_starting_deck_codes.csv"
OUT_CSV = EXISTING_CSV
OUT_MD = ROOT / "docs" / "deck-codes.md"

WORKSHOP_ID = 3554281691
DECK_FORMAT_VERSION = 242
MOD_HEADER_HEX = f"{0:08x}{WORKSHOP_ID:08x}{DECK_FORMAT_VERSION:08x}"
UNIT_ID_BITS_FOR_MODDED_DECKS = 17
UNIT_ID_BITS_FOR_VANILLA_DECKS = 13
DIVISION_NDFBIN_ENV = "WARNO_YSMXWIFXWTO_DIVISION_NDFBIN"

TARGET_DIVISION_DESCRIPTORS = {
    ("NATO", "limited"): "Descriptor_Deck_Division_YSM_SIDE_NATO_BALANCED",
    ("NATO", "unlimited"): "Descriptor_Deck_Division_YSM_SIDE_NATO_UNLIMITED",
    ("PACT", "limited"): "Descriptor_Deck_Division_YSM_SIDE_PACT_BALANCED",
    ("PACT", "unlimited"): "Descriptor_Deck_Division_YSM_SIDE_PACT_UNLIMITED",
}

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def load_mod_serializer_ids() -> tuple[dict[tuple[str, str], int], dict[str, int]]:
    division_ndfbin = os.environ.get(DIVISION_NDFBIN_ENV)
    if not division_ndfbin:
        raise RuntimeError(
            f"Set {DIVISION_NDFBIN_ENV} to the current YSM x WiF x WTO Division.ndfbin. "
            "The generator needs the mod's current division and unit serializer IDs."
        )

    descriptor_to_id, unit_ids = extract_serializer_ids(Path(division_ndfbin))
    target_division_ids = {
        key: descriptor_to_id[descriptor] for key, descriptor in TARGET_DIVISION_DESCRIPTORS.items()
    }
    return target_division_ids, unit_ids


def normalize_descriptor(value: str) -> str:
    return value.strip().replace("$/GFX/Unit/", "").replace("$/GFX/Division/", "")


def parse_serializer_unit_ids(path: Path) -> dict[str, int]:
    text = read_text(path)
    match = re.search(r"UnitIds\s*=\s*MAP\s*\[(.*?)\n\s*\]", text, flags=re.S)
    if not match:
        raise RuntimeError(f"Could not find UnitIds map in {path}")

    unit_ids: dict[str, int] = {}
    for descriptor, raw_id in re.findall(r"\(([^,\)]+),\s*(\d+)\)", match.group(1)):
        unit_ids[normalize_descriptor(descriptor)] = int(raw_id)
    return unit_ids


def parse_serializer_division_ids(path: Path) -> dict[str, int]:
    text = read_text(path)
    match = re.search(r"DivisionIds\s*=\s*MAP\s*\[(.*?)\n\s*\]", text, flags=re.S)
    if not match:
        raise RuntimeError(f"Could not find DivisionIds map in {path}")

    division_ids: dict[str, int] = {}
    for descriptor, raw_id in re.findall(r"\(([^,\)]+),\s*(\d+)\)", match.group(1)):
        division_ids[normalize_descriptor(descriptor)] = int(raw_id)
    return division_ids


def parse_deck_packs(path: Path) -> dict[str, dict[str, object]]:
    text = read_text(path)
    packs: dict[str, dict[str, object]] = {}
    pattern = re.compile(
        r"(?m)^(\S+)\s+is\s+DeckPackDescriptor\s*\(\s*(.*?)(?=\n\)\s*(?:\n\S+\s+is\s+DeckPackDescriptor|\Z))",
        re.S,
    )
    for match in pattern.finditer(text):
        name, body = match.group(1), match.group(2)
        unit_match = re.search(r"Unit\s*=\s*\$/GFX/Unit/(\S+)", body)
        if not unit_match:
            continue
        transport_match = re.search(r"Transport\s*=\s*\$/GFX/Unit/(\S+)", body)
        xp_match = re.search(r"Xp\s*=\s*(\d+)", body)
        packs[name] = {
            "unit": unit_match.group(1),
            "transport": transport_match.group(1) if transport_match else None,
            "xp": int(xp_match.group(1)) if xp_match else 0,
        }
    return packs


def parse_decks(path: Path) -> dict[str, dict[str, object]]:
    text = read_text(path)
    decks: dict[str, dict[str, object]] = {}
    pattern = re.compile(
        r"(?m)^export\s+(\S+)\s+is\s+TDeckDescriptor\s*\(\s*(.*?)(?=\n\)\s*(?:\nexport\s+\S+\s+is\s+TDeckDescriptor|\Z))",
        re.S,
    )
    for match in pattern.finditer(text):
        name, body = match.group(1), match.group(2)
        division_match = re.search(r"DeckDivision\s*=\s*\$/GFX/Division/(\S+)", body)
        deck_name_match = re.search(r'DeckName\s*=\s*"([^"]+)"', body)
        list_match = re.search(r"DeckPackList\s*=\s*\[(.*?)\]", body, flags=re.S)
        if not division_match or not list_match:
            continue
        packs = re.findall(r"~/([A-Za-z0-9_]+)", list_match.group(1))
        decks[name] = {
            "division": division_match.group(1),
            "deck_name_key": deck_name_match.group(1) if deck_name_match else "",
            "packs": packs,
        }
    return decks


def encode_fixed(value: int, length: int = 5) -> str:
    return format(value, "b").zfill(length)


def encode_length_leading(value: int) -> str:
    data = format(value, "b")
    return encode_fixed(len(data), 5) + data


def encode_deck(
    cards: list[tuple[int, int, int]],
    division_id: int,
    *,
    modded: bool = True,
    unit_id_bits: int = UNIT_ID_BITS_FOR_MODDED_DECKS,
) -> str:
    bits = encode_length_leading(3)
    bits += encode_length_leading(1 if modded else 0)
    if modded:
        bits += format(int(MOD_HEADER_HEX, 16), "096b")
    bits += encode_length_leading(division_id)
    bits += encode_length_leading(len(cards))

    xp_bits = max(1, max((xp.bit_length() for xp, _, _ in cards), default=1))
    bits += encode_fixed(xp_bits)
    bits += encode_fixed(unit_id_bits)

    for xp, unit_id, transport_id in cards:
        bits += encode_fixed(xp, xp_bits)
        bits += encode_fixed(unit_id, unit_id_bits)
        bits += encode_fixed(transport_id, unit_id_bits)

    bits += encode_length_leading(0)
    if len(bits) % 8:
        bits += "0" * (8 - (len(bits) % 8))
    data = bytes(int(bits[index : index + 8], 2) for index in range(0, len(bits), 8))
    return base64.b64encode(data).decode("ascii")


def build_cards(deck: dict[str, object], packs: dict[str, dict[str, object]], unit_ids: dict[str, int]) -> list[tuple[int, int, int]]:
    cards: list[tuple[int, int, int]] = []
    for pack_name in deck["packs"]:
        pack = packs[str(pack_name)]
        unit_descriptor = str(pack["unit"])
        transport_descriptor = pack["transport"]
        if unit_descriptor not in unit_ids:
            raise RuntimeError(f"Missing unit serializer id for {unit_descriptor}")
        unit_id = unit_ids[unit_descriptor] + 1
        transport_id = 0
        if transport_descriptor:
            transport_name = str(transport_descriptor)
            if transport_name not in unit_ids:
                raise RuntimeError(f"Missing transport serializer id for {transport_name}")
            transport_id = unit_ids[transport_name] + 1
        cards.append((int(pack["xp"]), unit_id, transport_id))
    return cards


def write_markdown(rows: list[dict[str, str]]) -> None:
    lines = [
        "# YSM x WiF x WTO - Vanilla Starting Deck Import Codes",
        "",
        "Generated from WARNO vanilla `base.zip` starting decks and re-encoded for YSM Freedom divisions.",
        "",
        "Use the Limited codes first. The Unlimited codes target the Freedom unlimited divisions.",
        "",
        "The Limited and Unlimited codes match current in-game exports from YSM x WiF x WTO: Workshop header, YSM Freedom division IDs, and 17-bit unit IDs.",
        "",
        "Vanilla official icon codes are normal non-modded deck codes with the original division ID/icon.",
        "",
        "Modded official icon codes keep the Workshop header but use the original division ID. They were observed to fail in WARNO under YSM x WiF x WTO.",
        "",
        "| Alliance | Deck | Cards | Limited code | Unlimited code | Vanilla official icon code | Modded official icon code |",
        "|---|---:|---:|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['alliance']} | {row['name']} | {row['cards']} | "
            f"`{row['ysmxwifxwto_limited_code']}` | `{row['ysmxwifxwto_unlimited_code']}` | "
            f"`{row['vanilla_official_icon_code']}` | `{row['ysmxwifxwto_official_icon_code']}` |"
        )
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    base_unit_ids = parse_serializer_unit_ids(BASE_DECK_DIR / "DeckSerializer.ndf")
    division_ids = parse_serializer_division_ids(BASE_DECK_DIR / "DeckSerializer.ndf")
    target_division_ids, mod_unit_ids = load_mod_serializer_ids()
    packs = parse_deck_packs(BASE_DECK_DIR / "DeckPacks.ndf")
    decks = parse_decks(BASE_DECK_DIR / "Decks.ndf")

    with EXISTING_CSV.open("r", newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    for row in rows:
        deck = decks[row["source_deck_descriptor"]]
        base_cards = build_cards(deck, packs, base_unit_ids)
        mod_cards = build_cards(deck, packs, mod_unit_ids)
        alliance = row["alliance"]
        row["source_division"] = str(deck["division"])
        row["cards"] = str(len(base_cards))
        row["vanilla_deck_name_key"] = str(deck["deck_name_key"])
        row["ysmxwifxwto_limited_code"] = encode_deck(
            mod_cards,
            target_division_ids[(alliance, "limited")],
            unit_id_bits=UNIT_ID_BITS_FOR_MODDED_DECKS,
        )
        row["ysmxwifxwto_unlimited_code"] = encode_deck(
            mod_cards,
            target_division_ids[(alliance, "unlimited")],
            unit_id_bits=UNIT_ID_BITS_FOR_MODDED_DECKS,
        )
        source_division = str(deck["division"])
        if source_division not in division_ids:
            raise RuntimeError(f"Missing division serializer id for {source_division}")
        row["vanilla_official_icon_code"] = encode_deck(
            base_cards,
            division_ids[source_division],
            modded=False,
            unit_id_bits=UNIT_ID_BITS_FOR_VANILLA_DECKS,
        )
        row["ysmxwifxwto_official_icon_code"] = encode_deck(mod_cards, division_ids[source_division])

    fieldnames = [
        "source_division",
        "name",
        "alliance",
        "cards",
        "source_deck_descriptor",
        "vanilla_deck_name_key",
        "ysmxwifxwto_limited_code",
        "ysmxwifxwto_unlimited_code",
        "vanilla_official_icon_code",
        "ysmxwifxwto_official_icon_code",
    ]
    with OUT_CSV.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    write_markdown(rows)
    print(f"Wrote {len(rows)} decks")
    print(
        "Target YSM division IDs: "
        + ", ".join(f"{alliance} {mode}={raw_id}" for (alliance, mode), raw_id in target_division_ids.items())
    )
    print(f"Loaded {len(mod_unit_ids)} YSM unit IDs")
    print(OUT_CSV)
    print(OUT_MD)


if __name__ == "__main__":
    main()

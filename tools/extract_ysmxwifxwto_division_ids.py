from __future__ import annotations

import argparse
import struct
from dataclasses import dataclass
from pathlib import Path


TARGET_DIVISION_DESCRIPTORS = {
    "NATO limited": "Descriptor_Deck_Division_YSM_SIDE_NATO_BALANCED",
    "NATO unlimited": "Descriptor_Deck_Division_YSM_SIDE_NATO_UNLIMITED",
    "PACT limited": "Descriptor_Deck_Division_YSM_SIDE_PACT_BALANCED",
    "PACT unlimited": "Descriptor_Deck_Division_YSM_SIDE_PACT_UNLIMITED",
}

REFERENCE_TYPE = 0x00000009
OBJECT_REFERENCE_TYPE = 0xBBBBBBBB
TRANS_REFERENCE_TYPE = 0xAAAAAAAA
UINT32_TYPE = 0x00000003
MAP_LIST_TYPE = 0x00000012
LIST_TYPE = 0x00000011
WIDE_STRING_TYPE = 0x00000008

FIXED_TYPE_SIZES = {
    0x00000000: 1,  # bool
    0x00000001: 1,  # int8
    25: 2,  # int16
    0x00000002: 4,  # int32
    UINT32_TYPE: 4,
    0x00000005: 4,  # float32
    0x00000006: 8,  # float64
    33: 8,  # float64 variant
    26: 16,  # guid
    0x0000000B: 12,  # vector
    0x0000000C: 16,  # color128
    0x0000000D: 4,  # color32
    0x00000007: 4,  # string table reference
    28: 4,  # file string table reference
    29: 8,  # localisation hash
    OBJECT_REFERENCE_TYPE: 8,
    TRANS_REFERENCE_TYPE: 4,
}


@dataclass(frozen=True)
class NdfbinData:
    data: bytes
    section_payload_bias: int


class Reader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.pos = 0

    def u32(self) -> int:
        value = struct.unpack_from("<I", self.data, self.pos)[0]
        self.pos += 4
        return value

    def read(self, length: int) -> bytes:
        value = self.data[self.pos : self.pos + length]
        if len(value) != length:
            raise EOFError(f"Unexpected end of NDFBIN value at {self.pos}")
        self.pos += length
        return value


def read_ndfbin(path: Path) -> NdfbinData:
    data = path.read_bytes()
    if data[:4] != b"EUG0" or data[8:12] != b"CNDF":
        raise ValueError(f"{path} is not an Eugen NDFBIN file")

    compression = struct.unpack_from("<I", data, 12)[0]
    if compression == 2:
        if data[44:48] == b"\x28\xb5\x2f\xfd":
            try:
                from compression import zstd

                body = zstd.decompress(data[44:])
            except ImportError:
                try:
                    import zstandard
                except ImportError as exc:
                    raise RuntimeError(
                        "Install zstandard to read compressed WARNO NDFBIN files: python -m pip install zstandard"
                    ) from exc
                body = zstandard.ZstdDecompressor().decompress(data[44:])
            data = data[:44] + body
        return NdfbinData(data=data, section_payload_bias=4)

    if compression != 0:
        raise ValueError(f"Unsupported NDFBIN compression flag {compression} in {path}")

    return NdfbinData(data=data, section_payload_bias=0)


def parse_toc(ndfbin: NdfbinData) -> dict[str, tuple[int, int]]:
    data = ndfbin.data
    header_toc_offset = struct.unpack_from("<I", data, 16)[0] + ndfbin.section_payload_bias
    if data[header_toc_offset : header_toc_offset + 4] == b"TOC0":
        toc_offset = header_toc_offset
    else:
        toc_offset = data.rfind(b"TOC0")
    if toc_offset < 0:
        raise ValueError("Could not find TOC0 footer")

    count = struct.unpack_from("<I", data, toc_offset + 4)[0]
    pos = toc_offset + 8
    sections: dict[str, tuple[int, int]] = {}
    for _ in range(count):
        name = data[pos : pos + 4].decode("ascii")
        _, offset, _, size, _ = struct.unpack_from("<IIIII", data, pos + 4)
        sections[name] = (offset, size)
        pos += 24
    return sections


def section_payload(ndfbin: NdfbinData, sections: dict[str, tuple[int, int]], name: str) -> bytes:
    offset, size = sections[name]
    start = offset + ndfbin.section_payload_bias
    return ndfbin.data[start : start + size]


def parse_string_table(data: bytes) -> list[str]:
    reader = Reader(data)
    values: list[str] = []
    while reader.pos < len(data):
        length = reader.u32()
        values.append(reader.read(length).decode("latin-1"))
    return values


def parse_properties(data: bytes) -> list[tuple[str, int]]:
    reader = Reader(data)
    properties: list[tuple[str, int]] = []
    while reader.pos < len(data):
        length = reader.u32()
        name = reader.read(length).decode("latin-1")
        class_id = reader.u32()
        properties.append((name, class_id))
    return properties


def read_value(reader: Reader) -> tuple[str, object]:
    value_type = reader.u32()
    if value_type == REFERENCE_TYPE:
        value_type = reader.u32()

    if value_type == MAP_LIST_TYPE:
        count = reader.u32()
        return ("MapList", [(read_value(reader), read_value(reader)) for _ in range(count)])

    if value_type == LIST_TYPE:
        count = reader.u32()
        return ("List", [read_value(reader) for _ in range(count)])

    if value_type == WIDE_STRING_TYPE:
        length = reader.u32()
        return ("WideString", reader.read(length).decode("utf-16le", errors="replace"))

    if value_type == OBJECT_REFERENCE_TYPE:
        instance_id, class_id = struct.unpack("<II", reader.read(8))
        return ("ObjectReference", (instance_id, class_id))

    if value_type == TRANS_REFERENCE_TYPE:
        return ("TransTableReference", struct.unpack("<I", reader.read(4))[0])

    if value_type == UINT32_TYPE:
        return ("UInt32", struct.unpack("<I", reader.read(4))[0])

    size = FIXED_TYPE_SIZES.get(value_type)
    if size is None:
        raise ValueError(f"Unsupported NDFBIN value type 0x{value_type:08x}")
    return (f"Type{value_type}", reader.read(size))


def parse_first_object(data: bytes) -> tuple[int, list[tuple[int, tuple[str, object]]]]:
    separator = b"\xab\xab\xab\xab"
    end = data.find(separator)
    if end < 0:
        raise ValueError("Could not find first object separator")

    reader = Reader(data[:end])
    class_id = reader.u32()
    values: list[tuple[int, tuple[str, object]]] = []
    while reader.pos < end:
        property_id = reader.u32()
        values.append((property_id, read_value(reader)))
    return class_id, values


def extract_serializer_ids(path: Path) -> tuple[dict[str, int], dict[str, int]]:
    ndfbin = read_ndfbin(path)
    sections = parse_toc(ndfbin)
    classes = parse_string_table(section_payload(ndfbin, sections, "CLAS"))
    properties = parse_properties(section_payload(ndfbin, sections, "PROP"))
    trans = parse_string_table(section_payload(ndfbin, sections, "TRAN"))

    object_payload = section_payload(ndfbin, sections, "OBJE")
    class_id, object_values = parse_first_object(object_payload)
    if classes[class_id] != "TDeckSerializerEntries":
        raise ValueError(f"Expected first object to be TDeckSerializerEntries, got {classes[class_id]}")

    division_map: list[tuple[tuple[str, object], tuple[str, object]]] | None = None
    unit_map: list[tuple[tuple[str, object], tuple[str, object]]] | None = None
    for property_id, value in object_values:
        property_name, _ = properties[property_id]
        if property_name == "DivisionIds":
            if value[0] != "MapList":
                raise ValueError("DivisionIds is not a MapList")
            division_map = value[1]  # type: ignore[assignment]
        elif property_name == "UnitIds":
            if value[0] != "MapList":
                raise ValueError("UnitIds is not a MapList")
            unit_map = value[1]  # type: ignore[assignment]

    if division_map is None:
        raise ValueError("Could not find DivisionIds on TDeckSerializerEntries")
    if unit_map is None:
        raise ValueError("Could not find UnitIds on TDeckSerializerEntries")

    object_id_to_serializer_id: dict[int, int] = {}
    for key, value in division_map:
        if key[0] == "ObjectReference" and value[0] == "UInt32":
            object_id, _ = key[1]  # type: ignore[misc]
            object_id_to_serializer_id[int(object_id)] = int(value[1])

    expr_values = struct.unpack("<" + "I" * (len(section_payload(ndfbin, sections, "EXPR")) // 4), section_payload(ndfbin, sections, "EXPR"))
    descriptor_to_id: dict[str, int] = {}
    for descriptor in TARGET_DIVISION_DESCRIPTORS.values():
        try:
            trans_index = trans.index(descriptor)
        except ValueError as exc:
            raise ValueError(f"Could not find {descriptor} in TRAN table") from exc

        matches = [
            expr_values[index + 1]
            for index in range(len(expr_values) - 2)
            if expr_values[index] == trans_index
            and expr_values[index + 2] == 0
            and expr_values[index + 1] in object_id_to_serializer_id
        ]
        if len(matches) != 1:
            raise ValueError(f"Expected one export match for {descriptor}, found {len(matches)}")
        descriptor_to_id[descriptor] = object_id_to_serializer_id[matches[0]]

    unit_ids: dict[str, int] = {}
    for key, value in unit_map:
        if key[0] != "TransTableReference" or value[0] != "UInt32":
            continue
        trans_index = int(key[1])
        if trans_index >= len(trans):
            raise ValueError(f"UnitIds references missing TRAN index {trans_index}")
        unit_ids[trans[trans_index]] = int(value[1])

    if not unit_ids:
        raise ValueError("Could not extract any UnitIds from TDeckSerializerEntries")

    return descriptor_to_id, unit_ids


def extract_division_ids(path: Path) -> dict[str, int]:
    division_ids, _ = extract_serializer_ids(path)
    return division_ids


def extract_unit_ids(path: Path) -> dict[str, int]:
    _, unit_ids = extract_serializer_ids(path)
    return unit_ids


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract YSM serializer IDs from compiled WARNO Division.ndfbin.")
    parser.add_argument("division_ndfbin", type=Path)
    args = parser.parse_args()

    descriptor_to_id, unit_ids = extract_serializer_ids(args.division_ndfbin)
    for label, descriptor in TARGET_DIVISION_DESCRIPTORS.items():
        print(f"{label:14} {descriptor_to_id[descriptor]:5} {descriptor}")
    print(f"Unit IDs       {len(unit_ids):5} entries")


if __name__ == "__main__":
    main()

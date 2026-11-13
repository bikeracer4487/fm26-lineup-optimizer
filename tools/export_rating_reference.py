#!/usr/bin/env python3
"""Export rating reference data from the Python rating_calculator for the Swift engine.

Run from the repository root:  python3 tools/export_rating_reference.py
Standard library only. Writes exactly two files:

  LineupEngine/Sources/LineupEngine/Resources/rating_tables.json
    {"positionWeights":  {<Position raw value, 14 of them>: {<attribute>: weight}},
     "consensusBonuses": {"<python table key>|<role>": {<attribute>: weight}},
     "thresholds":       {<role>: {<attribute>: minimum}}}

  LineupEngine/Tests/LineupEngineTests/Fixtures/reference/rating_reference_fm26.json
    {"attributeNames": [the 40 engine attribute names, sorted],
     "cases": [ one entry per player and active slot, sorted by player name then slot:
       {"player": name, "slot": "D_CL", "currentAbility": CA (number),
        "attributes":  {<attribute canonical name>: number, ... 40 entries},
        "familiarity": {<Position raw value>: number, ...  positions used by the tactic},
        "ipPosition": "D (C)", "ipRole": "...", "oopPosition": "D (C)", "oopRole": "...",
        "ipRating":  calculate_role_rating(player, ip_pos, ip_role, 'IP'),
        "oopRating": calculate_role_rating(player, oop_pos, oop_role, 'OOP'),
        "combinedRating": calculate_combined_rating(player, ip_pos, ip_role, oop_pos, oop_role)}]}
Positions are Swift Position raw values; all ratings are as returned by Python, unrounded further.
"""
import csv
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
import rating_calculator as rc  # noqa: E402

TABLES_OUT = os.path.join(ROOT, "LineupEngine/Sources/LineupEngine/Resources/rating_tables.json")
REFERENCE_OUT = os.path.join(ROOT, "LineupEngine/Tests/LineupEngineTests/Fixtures/reference/rating_reference_fm26.json")

# Python position key -> Swift Position raw value
SWIFT_POSITION = {
    "GK": "GK", "D(L)": "D (L)", "D(C)": "D (C)", "D(R)": "D (R)",
    "WB(L)": "WB (L)", "WB(R)": "WB (R)", "DM": "DM",
    "M(L)": "M (L)", "M(C)": "M (C)", "M(R)": "M (R)",
    "AM(L)": "AM (L)", "AM(C)": "AM (C)", "AM(R)": "AM (R)", "ST": "ST (C)",
}


def python_position(slot):
    group, _, side = slot.partition("_")
    if group == "GK":
        return "GK"
    if group in ("DM", "ST"):
        return group
    if group in ("D", "M", "AM"):
        return f"{group}(C)" if side in ("C", "CL", "CR") else f"{group}({side})"
    if group == "WB":
        return f"WB({side})"
    raise ValueError(f"unknown slot {slot}")


def clean(value):
    text = str(value).replace("$", "").replace("£", "").replace("€", "").replace("%", "").replace(",", "").strip()
    number = float(text)
    return int(number) if number.is_integer() else number


def engine_attributes():
    names = set()
    for weights in rc.POSITION_WEIGHTS.values():
        names |= set(weights)
    for bonuses in rc.CONSENSUS_BONUSES.values():
        names |= set(bonuses)
    for thresholds in rc.THRESHOLDS.values():
        names |= set(thresholds)
    with open(os.path.join(ROOT, "docs/FM26_Roles_Attributes.json")) as f:
        roles = json.load(f)
    for groups in roles.values():
        for group in groups.values():
            for role in group.values():
                names |= set(role.get("key", [])) | set(role.get("important", []))
    return sorted(names)


def attribute_column(row, name):
    """The CSV column get_attribute_value resolves for this attribute, or None if it falls back to 10."""
    if name in row:
        return name
    mapped = rc.ATTRIBUTE_NAME_MAP.get(name)
    return mapped if mapped and mapped in row else None


def write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")


def export_tables():
    weights = {}
    for key, swift in SWIFT_POSITION.items():
        weights[swift] = dict(rc.POSITION_WEIGHTS[key])
        total = sum(weights[swift].values())
        assert abs(total - 1.0) < 0.001, f"{key} weights sum to {total}"
    assert len(weights) == 14
    write_json(TABLES_OUT, {
        "positionWeights": weights,
        "consensusBonuses": {f"{pos}|{role}": dict(v) for (pos, role), v in rc.CONSENSUS_BONUSES.items()},
        "thresholds": {role: dict(v) for role, v in rc.THRESHOLDS.items()},
    })


def export_reference():
    with open(os.path.join(ROOT, "ui/data/app_state.json")) as f:
        tactic = json.load(f)["tacticConfig"]
    slots = []
    for slot in sorted(tactic["ipPositions"]):
        ip_role = tactic["ipPositions"][slot]
        if ip_role is None:
            continue
        oop_slot = tactic["mapping"][slot]
        slots.append((slot, python_position(slot), ip_role, python_position(oop_slot), tactic["oopPositions"][oop_slot]))

    attrs = engine_attributes()
    with open(os.path.join(ROOT, "players-current.csv"), newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    cases, skipped = [], 0
    for row in sorted(rows, key=lambda r: r["Name"]):
        columns = ["CA"] + [c for c in (attribute_column(row, a) for a in attrs) if c]
        for _, ip_pos, _, oop_pos, _ in slots:
            columns += [rc.get_familiarity_column(ip_pos), rc.get_familiarity_column(oop_pos)]
        if any(c not in row or row[c] is None or row[c].strip() == "" for c in columns):
            skipped += 1
            continue
        attributes = {a: clean(rc.get_attribute_value(row, a)) for a in attrs}
        for slot, ip_pos, ip_role, oop_pos, oop_role in slots:
            familiarity = {SWIFT_POSITION[p]: clean(row[rc.get_familiarity_column(p)]) for p in (ip_pos, oop_pos)}
            cases.append({
                "player": row["Name"], "slot": slot, "currentAbility": clean(row["CA"]),
                "attributes": attributes, "familiarity": familiarity,
                "ipPosition": SWIFT_POSITION[ip_pos], "ipRole": ip_role,
                "oopPosition": SWIFT_POSITION[oop_pos], "oopRole": oop_role,
                "ipRating": rc.calculate_role_rating(row, ip_pos, ip_role, "IP"),
                "oopRating": rc.calculate_role_rating(row, oop_pos, oop_role, "OOP"),
                "combinedRating": rc.calculate_combined_rating(row, ip_pos, ip_role, oop_pos, oop_role),
            })
    write_json(REFERENCE_OUT, {"attributeNames": attrs, "cases": cases})
    missing = [a for a in attrs if attribute_column(rows[0], a) is None]
    print(f"engine attributes: {len(attrs)} (not in CSV, Python falls back to 10: {missing})")
    print(f"players read: {len(rows)}, skipped for blank cells: {skipped}, written: {len(rows) - skipped}")
    print(f"active slots: {len(slots)}, cases written: {len(cases)}")


if __name__ == "__main__":
    export_tables()
    export_reference()

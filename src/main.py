'''
 Copyright (C) 2026  Brenno Almeida

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 3.

 plates is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
'''

from dataclasses import asdict, dataclass
from decimal import Decimal, InvalidOperation
from fractions import Fraction
from math import lcm
from typing import Dict, List, Optional, Tuple

from ut_components import setup

APP_NAME = "plates.brennoflavio"
PLATES_KEY = "plates"
BARS_KEY = "bars"
SEED_DONE_KEY = "seed.initial_data_done"

setup(APP_NAME)

from ut_components.kv import KV
from ut_components.utils import dataclass_to_dict


@dataclass
class StandardResponse:
    success: bool
    message: str = ""


@dataclass
class WeightedItem:
    itemName: str = ""
    itemWeight: str = ""


@dataclass
class WeightedItemsResponse:
    success: bool
    items: List[WeightedItem]
    message: str = ""


@dataclass
class PlateLoad:
    itemWeight: str
    count: int


@dataclass
class CalculationResponse:
    success: bool
    bar: WeightedItem
    targetWeight: str
    achievedTotalWeight: str
    targetSideWeight: str
    achievedSideWeight: str
    plates: List[PlateLoad]
    exactMatch: bool
    note: str = ""
    message: str = ""


MAX_WEIGHT = Decimal("2000")
MAX_DECIMAL_PLACES = 2

SEED_ITEMS: Dict[str, List[WeightedItem]] = {
    PLATES_KEY: [
        WeightedItem(itemWeight="25"),
        WeightedItem(itemWeight="20"),
        WeightedItem(itemWeight="15"),
        WeightedItem(itemWeight="10"),
        WeightedItem(itemWeight="5"),
        WeightedItem(itemWeight="2"),
        WeightedItem(itemWeight="1"),
    ],
    BARS_KEY: [
        WeightedItem(itemName="standard", itemWeight="20"),
        WeightedItem(itemName="short", itemWeight="15"),
        WeightedItem(itemName="ez bar", itemWeight="7.5"),
        WeightedItem(itemName="no bar", itemWeight="0"),
    ],
}


def _storage_key(items_key: str) -> str:
    return f"items.{items_key}"


def _seed_items(items_key: str) -> List[WeightedItem]:
    return SEED_ITEMS.get(items_key, [])


def _fraction_from_weight(raw_weight: str, label: str = "Weight") -> Fraction:
    weight = str(raw_weight).strip()
    if weight == "":
        raise ValueError(f"{label} is required")

    try:
        decimal_weight = Decimal(weight)
    except InvalidOperation as error:
        raise ValueError(f"{label} must be a valid number") from error

    if decimal_weight < 0:
        raise ValueError(f"{label} cannot be negative")

    if -decimal_weight.as_tuple().exponent > MAX_DECIMAL_PLACES:
        raise ValueError(f"{label} can have at most {MAX_DECIMAL_PLACES} decimal places")

    if decimal_weight > MAX_WEIGHT:
        raise ValueError(f"{label} cannot be greater than {_fraction_to_string(Fraction(MAX_WEIGHT))} kg")

    return Fraction(decimal_weight)


def _fraction_to_string(value: Fraction) -> str:
    if value == 0:
        return "0"

    decimal_value = Decimal(value.numerator) / Decimal(value.denominator)
    formatted = format(decimal_value.normalize(), "f")
    if "." in formatted:
        formatted = formatted.rstrip("0").rstrip(".")
    return formatted or "0"


def _parse_item(items_key: str, raw_item: Dict) -> WeightedItem:
    item_name = str(raw_item.get("itemName", "")).strip()
    if items_key == PLATES_KEY:
        item_name = ""

    return WeightedItem(
        itemName=item_name,
        itemWeight=str(raw_item.get("itemWeight", "")).strip(),
    )


def _parse_items(items_key: str, raw_items: List[Dict]) -> List[WeightedItem]:
    return [_parse_item(items_key, raw_item) for raw_item in raw_items]


def _load_saved_items(items_key: str) -> List[WeightedItem]:
    with KV() as kv:
        raw_items = kv.get(_storage_key(items_key), [], False) or []

    return _parse_items(items_key, raw_items)


def _normalized_plate_weights(plates: List[WeightedItem]) -> List[Tuple[Fraction, str]]:
    unique_weights = set()
    for plate in plates:
        try:
            weight = _fraction_from_weight(plate.itemWeight, "Plate weight")
        except ValueError:
            continue

        if weight > 0:
            unique_weights.add(weight)

    return [(weight, _fraction_to_string(weight)) for weight in sorted(unique_weights, reverse=True)]


def _calculate_side_plate_loads(side_weight: Fraction, plates: List[WeightedItem]) -> Optional[Tuple[Fraction, List[PlateLoad]]]:
    if side_weight == 0:
        return Fraction(0), []

    normalized_plates = _normalized_plate_weights(plates)
    if not normalized_plates:
        return None

    scale = lcm(side_weight.denominator, *[weight.denominator for weight, _ in normalized_plates])
    target_scaled = int(side_weight * scale)
    plate_values = [int(weight * scale) for weight, _ in normalized_plates]
    upper_bound = target_scaled + max(plate_values) - 1

    min_plate_counts: List[Optional[int]] = [None] * (upper_bound + 1)
    previous_steps: List[Optional[Tuple[int, int]]] = [None] * (upper_bound + 1)
    min_plate_counts[0] = 0

    for total in range(1, upper_bound + 1):
        best_count = None
        best_previous = None

        for plate_index, plate_value in enumerate(plate_values):
            if total < plate_value:
                continue

            previous_total = total - plate_value
            previous_count = min_plate_counts[previous_total]
            if previous_count is None:
                continue

            candidate_count = previous_count + 1
            if best_count is None or candidate_count < best_count:
                best_count = candidate_count
                best_previous = (previous_total, plate_index)

        min_plate_counts[total] = best_count
        previous_steps[total] = best_previous

    achieved_scaled = None
    for total in range(target_scaled, upper_bound + 1):
        if min_plate_counts[total] is not None:
            achieved_scaled = total
            break

    if achieved_scaled is None:
        return None

    plate_counts = [0] * len(normalized_plates)
    current_total = achieved_scaled
    while current_total > 0:
        previous_step = previous_steps[current_total]
        if previous_step is None:
            break

        previous_total, plate_index = previous_step
        plate_counts[plate_index] += 1
        current_total = previous_total

    achieved_side_weight = Fraction(achieved_scaled, scale)
    plate_loads = [
        PlateLoad(itemWeight=normalized_plates[index][1], count=count)
        for index, count in enumerate(plate_counts)
        if count > 0
    ]

    return achieved_side_weight, plate_loads


@dataclass_to_dict
def seed_data() -> StandardResponse:
    with KV() as kv:
        if kv.get(SEED_DONE_KEY, False) is True:
            return StandardResponse(success=True)

        for items_key in SEED_ITEMS:
            kv.put(_storage_key(items_key), [asdict(item) for item in _seed_items(items_key)])

        kv.put(SEED_DONE_KEY, True)

    return StandardResponse(success=True)


@dataclass_to_dict
def load_weighted_items(items_key: str) -> WeightedItemsResponse:
    if items_key not in SEED_ITEMS:
        return WeightedItemsResponse(success=False, items=[], message="Unknown items key")

    return WeightedItemsResponse(success=True, items=_load_saved_items(items_key))


@dataclass_to_dict
def save_weighted_items(items_key: str, items: List[Dict]) -> StandardResponse:
    if items_key not in SEED_ITEMS:
        return StandardResponse(success=False, message="Unknown items key")

    parsed_items = _parse_items(items_key, items)

    with KV() as kv:
        kv.put(_storage_key(items_key), [asdict(item) for item in parsed_items])

    return StandardResponse(success=True)


@dataclass_to_dict
def calculate_barbell_plates(bar: Dict, target_weight: str) -> CalculationResponse:
    parsed_bar = _parse_item(BARS_KEY, bar)

    try:
        bar_weight = _fraction_from_weight(parsed_bar.itemWeight, "Bar weight")
        requested_target_weight = _fraction_from_weight(str(target_weight), "Target weight")
    except ValueError as error:
        return CalculationResponse(
            success=False,
            bar=parsed_bar,
            targetWeight=str(target_weight),
            achievedTotalWeight="0",
            targetSideWeight="0",
            achievedSideWeight="0",
            plates=[],
            exactMatch=False,
            message=str(error),
        )

    if requested_target_weight < bar_weight:
        return CalculationResponse(
            success=True,
            bar=parsed_bar,
            targetWeight=_fraction_to_string(requested_target_weight),
            achievedTotalWeight=_fraction_to_string(bar_weight),
            targetSideWeight="0",
            achievedSideWeight="0",
            plates=[],
            exactMatch=False,
            note="Target weight is lower than the selected bar weight. Using the bar only.",
        )

    target_side_weight = (requested_target_weight - bar_weight) / 2
    saved_plates = _load_saved_items(PLATES_KEY)
    calculation = _calculate_side_plate_loads(target_side_weight, saved_plates)

    if calculation is None:
        return CalculationResponse(
            success=False,
            bar=parsed_bar,
            targetWeight=_fraction_to_string(requested_target_weight),
            achievedTotalWeight=_fraction_to_string(bar_weight),
            targetSideWeight=_fraction_to_string(target_side_weight),
            achievedSideWeight="0",
            plates=[],
            exactMatch=False,
            message="No valid plates are available for calculation.",
        )

    achieved_side_weight, plate_loads = calculation
    achieved_total_weight = bar_weight + (achieved_side_weight * 2)
    exact_match = achieved_side_weight == target_side_weight
    note = ""

    if not exact_match:
        note = (
            "Exact target is not possible with the available plates. "
            f"Using {_fraction_to_string(achieved_total_weight)} kg instead of {_fraction_to_string(requested_target_weight)} kg."
        )

    return CalculationResponse(
        success=True,
        bar=parsed_bar,
        targetWeight=_fraction_to_string(requested_target_weight),
        achievedTotalWeight=_fraction_to_string(achieved_total_weight),
        targetSideWeight=_fraction_to_string(target_side_weight),
        achievedSideWeight=_fraction_to_string(achieved_side_weight),
        plates=plate_loads,
        exactMatch=exact_match,
        note=note,
    )

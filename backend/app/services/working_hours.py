"""Helpers for structured place working hours.

The backend stores structured per-day opening hours in the existing
`working_hours_json` (JSONB) column. The format is:

{
  "monday":    {"type": "open24"},
  "tuesday":   {"type": "regular", "intervals": [{"open": "09:00", "close": "17:00"}]},
  "wednesday": {"type": "regular", "intervals": [{"open": "11:00", "close": "15:00"},
                                                 {"open": "18:00", "close": "01:00"}]},
  "friday":    {"type": "closed"}
}

The 7 days are: saturday, sunday, monday, tuesday, wednesday, thursday, friday.
A "regular" day may have several intervals; a "close" <= "open" time means the
interval wraps past midnight (e.g. 18:00 -> 01:00). "open24" means all day.

These helpers compute an "open now" boolean that is compatible with the data
model's existing `is_open` flag used by Explore/Map/`/places/open`.
"""

from __future__ import annotations

import datetime as _dt

DAYS = [
    "saturday",
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
]

# Python's datetime.weekday(): Monday=0 ... Sunday=6
_WEEKDAY_INDEX_TO_KEY = {
    0: "monday",
    1: "tuesday",
    2: "wednesday",
    3: "thursday",
    4: "friday",
    5: "saturday",
    6: "sunday",
}


def _minutes(value: str) -> int:
    hour, minute = value.split(":")
    return int(hour) * 60 + int(minute)


def _current_day_key(now: _dt.datetime) -> str:
    return _WEEKDAY_INDEX_TO_KEY[now.weekday()]


def _day_open_minutes(
    day: dict | None,
    now: _dt.datetime,
) -> bool:
    if not day:
        return False

    day_type = day.get("type")

    if day_type == "open24":
        return True

    if day_type != "regular":
        return False

    current = now.hour * 60 + now.minute

    for interval in day.get("intervals", []) or []:
        try:
            open_m = _minutes(interval["open"])
            close_m = _minutes(interval["close"])
        except (KeyError, TypeError, ValueError):
            continue

        if open_m == close_m:
            # Degenerate zero-length interval is treated as all-day.
            return True

        if open_m < close_m:
            if open_m <= current < close_m:
                return True
        else:
            # Interval wraps past midnight (e.g. 18:00 -> 01:00).
            if current >= open_m or current < close_m:
                return True

    return False


def is_open_now(
    working_hours: dict | None,
    now: _dt.datetime | None = None,
) -> bool:
    """Return True when the place is open at `now` based on its hours."""
    if not working_hours:
        return False

    current = now or _dt.datetime.now()

    # Open during today's schedule.
    day_key = _current_day_key(current)
    if _day_open_minutes(working_hours.get(day_key), current):
        return True

    # If yesterday was a "regular" day with an overnight interval that spills
    # into today's early hours (e.g. 18:00 -> 01:00), we may still be open.
    yesterday_key = DAYS[(DAYS.index(day_key) - 1) % len(DAYS)]
    yesterday = working_hours.get(yesterday_key)
    if yesterday and yesterday.get("type") == "regular":
        current_minutes = current.hour * 60 + current.minute
        for interval in yesterday.get("intervals", []) or []:
            try:
                close_m = _minutes(interval["close"])
                open_m = _minutes(interval["open"])
            except (KeyError, TypeError, ValueError):
                continue
            if close_m < open_m and current_minutes < close_m:
                return True

    return False


def flat_opening_hours(
    working_hours: dict | None,
) -> tuple[str | None, str | None]:
    """Return a single (opening, closing) pair for legacy flat columns.

    Uses the first open day / interval found in the week; used only so the
    existing `opening_time`/`closing_time` display columns still show
    something sensible.
    """
    if not working_hours:
        return None, None

    for day_key in DAYS:
        day = working_hours.get(day_key)
        if not day:
            continue
        if day.get("type") == "open24":
            return "00:00", "23:59"
        if day.get("type") == "regular":
            intervals = day.get("intervals", []) or []
            if intervals:
                first = intervals[0]
                return first.get("open"), first.get("close")

    return None, None
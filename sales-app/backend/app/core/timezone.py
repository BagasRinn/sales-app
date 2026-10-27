from datetime import date, datetime, timedelta, timezone
from typing import Optional, Tuple

UTC = timezone.utc


def device_timezone_offset_minutes(value: Optional[int]) -> int:
    """Normalize a device UTC offset. Indonesia is UTC+7/+8/+9."""
    if value is None:
        return 0
    return max(-14 * 60, min(14 * 60, int(value)))


def local_day_utc_bounds(
    target_date: date,
    timezone_offset_minutes: Optional[int] = None,
) -> Tuple[datetime, datetime]:
    """Return [start, end) UTC for a calendar date in the user's device timezone."""
    offset = timezone_offset_minutes
    if offset is None:
        local_tz = UTC
    else:
        local_tz = timezone(timedelta(minutes=device_timezone_offset_minutes(offset)))

    start_local = datetime.combine(target_date, datetime.min.time(), tzinfo=local_tz)
    end_local = start_local + timedelta(days=1)
    return start_local.astimezone(UTC), end_local.astimezone(UTC)


def local_now_for_date(timezone_offset_minutes: Optional[int] = None) -> datetime:
    """Return current datetime with device timezone offset, or UTC if omitted."""
    offset = timezone_offset_minutes
    if offset is None:
        return datetime.now(UTC)
    local_tz = timezone(timedelta(minutes=device_timezone_offset_minutes(offset)))
    return datetime.now(local_tz)

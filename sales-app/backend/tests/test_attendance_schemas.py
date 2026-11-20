"""Unit test schema payload webhook absensi (tanpa DB)."""
from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.schemas.schemas import WAAttendanceWebhookPayload


def _payload(**overrides) -> dict:
    data = {
        "sender_phone": "+62 812-0000-1234",
        "outlet_code": " out-01 ",
        "outlet_name": " Toko A ",
        "outlet_channel": " gt ",
        "message_timestamp": 1_700_000_000,
    }
    data.update(overrides)
    return data


def test_sender_phone_and_outlet_fields_are_normalized():
    payload = WAAttendanceWebhookPayload(**_payload())
    assert payload.sender_phone == "6281200001234"
    assert payload.outlet_code == "out-01"
    assert payload.outlet_name == "Toko A"
    assert payload.outlet_channel == "gt"


def test_epoch_seconds_becomes_aware_utc():
    payload = WAAttendanceWebhookPayload(**_payload())
    assert payload.message_timestamp == datetime.fromtimestamp(
        1_700_000_000, tz=timezone.utc
    )


def test_epoch_milliseconds_is_detected():
    payload = WAAttendanceWebhookPayload(
        **_payload(message_timestamp=1_700_000_000_000)
    )
    assert payload.message_timestamp == datetime.fromtimestamp(
        1_700_000_000, tz=timezone.utc
    )


def test_iso_string_timestamp_is_accepted():
    payload = WAAttendanceWebhookPayload(
        **_payload(message_timestamp="2026-01-02T03:04:05+08:00")
    )
    assert payload.message_timestamp == datetime(
        2026, 1, 1, 19, 4, 5, tzinfo=timezone.utc
    )


def test_naive_timestamp_is_treated_as_utc():
    payload = WAAttendanceWebhookPayload(
        **_payload(message_timestamp="2026-01-02T03:04:05")
    )
    assert payload.message_timestamp.tzinfo is not None
    assert payload.message_timestamp == datetime(
        2026, 1, 2, 3, 4, 5, tzinfo=timezone.utc
    )


@pytest.mark.parametrize("field", ["outlet_code", "outlet_name", "outlet_channel"])
def test_blank_outlet_fields_are_rejected(field):
    with pytest.raises(ValidationError):
        WAAttendanceWebhookPayload(**_payload(**{field: "   "}))


def test_blank_sender_phone_is_rejected():
    with pytest.raises(ValidationError):
        WAAttendanceWebhookPayload(**_payload(sender_phone="  "))

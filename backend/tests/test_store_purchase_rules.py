from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.services.store_purchase_service import StorePurchaseService


def item(**overrides):
    values = {
        "is_active": True,
        "available_from": None,
        "available_until": None,
        "stock": None,
        "price": 10,
        "ownership_duration_days": None,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def test_active_item_is_available():
    StorePurchaseService._validate_item(item())


def test_inactive_item_is_rejected():
    with pytest.raises(ValueError, match="inactive"):
        StorePurchaseService._validate_item(item(is_active=False))


def test_item_before_availability_is_rejected():
    with pytest.raises(ValueError, match="not available yet"):
        StorePurchaseService._validate_item(
            item(available_from=datetime.now(timezone.utc) + timedelta(minutes=1))
        )


def test_expired_item_is_rejected():
    with pytest.raises(ValueError, match="expired"):
        StorePurchaseService._validate_item(
            item(available_until=datetime.now(timezone.utc) - timedelta(minutes=1))
        )


def test_zero_stock_is_rejected():
    with pytest.raises(ValueError, match="out of stock"):
        StorePurchaseService._validate_item(item(stock=0))


def test_null_stock_is_unlimited():
    StorePurchaseService._validate_item(item(stock=None))


def test_negative_stock_is_rejected():
    with pytest.raises(ValueError, match="out of stock"):
        StorePurchaseService._validate_item(item(stock=-1))


def test_negative_price_is_rejected():
    with pytest.raises(ValueError, match="price is invalid"):
        StorePurchaseService._validate_item(item(price=-1))


def test_permanent_ownership_has_no_expiry():
    now = datetime.now(timezone.utc)
    assert StorePurchaseService._ownership_expiry(item(), now) is None
    assert (
        StorePurchaseService._ownership_expiry(
            item(ownership_duration_days=0),
            now,
        )
        is None
    )


def test_temporary_ownership_expiry_is_based_on_purchase_time():
    purchase_time = datetime(2026, 9, 3, tzinfo=timezone.utc)
    expiry = StorePurchaseService._ownership_expiry(
        item(ownership_duration_days=30),
        purchase_time,
    )
    assert expiry == purchase_time + timedelta(days=30)

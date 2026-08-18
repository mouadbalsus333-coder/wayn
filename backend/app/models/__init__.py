"""Data models for the WAYN backend."""

from app.models.admin_user import AdminUser
from app.models.role import Role
from app.models.permission import Permission

from app.models.category import Category
from app.models.place import Place
from app.models.user import User

from app.models import admin_associations
from app.models.favorite import UserFavorite
from app.models.review import PlaceReview

# ============================================================
# Wallet
# ============================================================

from app.models.wallet import UserWallet
from app.models.wallet_transaction import (
    WalletAsset,
    WalletTransaction,
    WalletTransactionStatus,
    WalletTransactionType,
)
from app.models.wallet_transfer import (
    WalletTransfer,
    WalletTransferStatus,
)

# ============================================================
# Store
# ============================================================

from app.models.store_category import StoreCategory
from app.models.store_item import (
    StoreItem,
    StoreItemCurrency,
    StoreItemType,
)
from app.models.store_banner import StoreBanner


__all__ = [
    # ========================================================
    # Admin / Roles / Permissions
    # ========================================================

    "AdminUser",
    "Role",
    "Permission",

    # ========================================================
    # Places / Categories / Users
    # ========================================================

    "Category",
    "Place",
    "User",
    "admin_associations",
    "UserFavorite",
    "PlaceReview",

    # ========================================================
    # Wallet
    # ========================================================

    "UserWallet",
    "WalletAsset",
    "WalletTransaction",
    "WalletTransactionStatus",
    "WalletTransactionType",
    "WalletTransfer",
    "WalletTransferStatus",

    # ========================================================
    # Store
    # ========================================================

    "StoreCategory",
    "StoreItem",
    "StoreItemCurrency",
    "StoreItemType",
    "StoreBanner",
]
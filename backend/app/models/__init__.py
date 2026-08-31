"""Data models for the WAYN backend."""

# ============================================================
# Admin / Roles / Permissions
# ============================================================

from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role

# ============================================================
# Places / Categories / Users
# ============================================================

from app.models.category import Category
from app.models.favorite import UserFavorite
from app.models.place import Place
from app.models.place_contribution import (
    PlaceContribution,
    PlaceContributionStatus,
    PlaceContributionType,
)
from app.models.review import PlaceReview
from app.models.user import User
from app.models.user_verification_code import UserVerificationCode

from app.models import admin_associations

# ============================================================
# Community
# ============================================================

from app.models.community import (
    CommunityComment,
    CommunityPost,
    CommunityPostLike,
    CommunityPostSave,
)

# ============================================================
# User Points
# ============================================================

from app.models.user_point_transaction import (
    UserPointTransaction,
    UserPointTransactionStatus,
    UserPointTransactionType,
)

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

from app.models.store_banner import StoreBanner
from app.models.store_category import StoreCategory
from app.models.store_item import (
    StoreItem,
    StoreItemCurrency,
    StoreItemType,
)


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
    "PlaceContribution",
    "PlaceContributionStatus",
    "PlaceContributionType",
    "User",
    "admin_associations",
    "UserFavorite",
    "PlaceReview",
    "UserVerificationCode",

    # ========================================================
    # Community
    # ========================================================

    "CommunityPost",
    "CommunityPostLike",
    "CommunityPostSave",
    "CommunityComment",

    # ========================================================
    # User Points
    # ========================================================

    "UserPointTransaction",
    "UserPointTransactionStatus",
    "UserPointTransactionType",

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

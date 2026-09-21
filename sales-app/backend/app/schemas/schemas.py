from pydantic import BaseModel, Field
from uuid import UUID
from typing import List, Optional
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    ADMIN = "ADMIN"
    SALES = "SALES"


class OrderStatus(str, Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"


# ==================== AUTH ====================

class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6, max_length=72)
    role: str = Field(..., description="ADMIN atau SALES")


class UserLogin(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str


# ==================== PRODUCTS ====================

class ProductBase(BaseModel):
    id: str
    nama_barang: str
    harga: int


class ProductCreate(ProductBase):
    stok_sistem: int = 0
    stok_booking: int = 0


class ProductUpdateStock(BaseModel):
    stok_sistem: int = Field(..., ge=0, description="Nilai stok_sistem baru")


class ProductResponse(BaseModel):
    id: str
    nama_barang: str
    harga: int
    stok_sistem: int
    stok_booking: int
    stok_tersedia: int
    perlu_ditinjau: Optional[bool] = None

    class Config:
        from_attributes = True


class SyncErrorItem(BaseModel):
    row: int
    sku: str
    reason: str


class SyncResultResponse(BaseModel):
    success: bool
    total_rows: int
    inserted: int
    updated: int
    skipped: int
    errors: List[SyncErrorItem]


# ==================== ORDERS ====================

class OrderItemCreate(BaseModel):
    product_id: str
    qty: int = Field(..., gt=0)


class OrderCreate(BaseModel):
    items: List[OrderItemCreate]
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None


class OrderItemResponse(BaseModel):
    id: UUID
    product_id: str
    qty: int
    harga_satuan: int = 0

    class Config:
        from_attributes = True


class OrderResponse(BaseModel):
    id: UUID
    sales_id: UUID
    status: str
    created_at: datetime
    expired_at: Optional[datetime]
    items: List[OrderItemResponse] = []
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None

    class Config:
        from_attributes = True


class OrderListResponse(BaseModel):
    id: UUID
    sales_id: UUID
    status: str
    created_at: datetime
    expired_at: Optional[datetime]
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None

    class Config:
        from_attributes = True


class OrderListWithItemsResponse(BaseModel):
    id: UUID
    sales_id: UUID
    sales_username: Optional[str] = None
    status: str
    created_at: datetime
    expired_at: Optional[datetime]
    items: List[OrderItemResponse] = []
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None

    class Config:
        from_attributes = True


class OrderStatusUpdate(BaseModel):
    status: str


# ==================== STOCK LOG ====================

class StokLogResponse(BaseModel):
    id: UUID
    product_id: str
    sumber: str
    field_terdampak: str
    delta: int
    nilai_sebelum: int
    nilai_sesudah: int
    actor_id: Optional[UUID]
    order_id: Optional[UUID]
    created_at: datetime

    class Config:
        from_attributes = True

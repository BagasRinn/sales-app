from pydantic import BaseModel, Field
from uuid import UUID
from typing import List, Optional
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    ADMIN = "ADMIN"
    MANAGER = "MANAGER"
    SALES = "SALES"


class OrderStatus(str, Enum):
    DRAFT = "DRAFT"
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"


# ==================== AUTH ====================

class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6, max_length=72)
    role: str = Field(..., description="ADMIN, MANAGER, atau SALES")
    nama: Optional[str] = Field(None, max_length=100)


class UserUpdate(BaseModel):
    """Edit user — semua field opsional, hanya yang dikirim yang berubah."""
    nama: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = Field(None, min_length=6, max_length=72)
    is_active: Optional[bool] = None


class UserResponse(BaseModel):
    id: UUID
    username: str
    nama: Optional[str] = None
    role: str
    is_active: bool = True
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserLogin(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    username: Optional[str] = None
    nama: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str


# ==================== PRODUCTS ====================

class ProductBase(BaseModel):
    id: str
    nama_barang: str
    harga: int
    kategori: Optional[str] = None
    satuan: Optional[str] = None


class ProductCreate(ProductBase):
    stok_sistem: int = 0
    stok_booking: int = 0
    kategori: Optional[str] = None
    satuan: Optional[str] = None


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
    kategori: Optional[str] = None
    satuan: Optional[str] = None

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
    needs_review: bool = False


# ==================== ORDERS ====================

class OrderItemCreate(BaseModel):
    product_id: str
    qty: int = Field(..., gt=0)
    discount_type: str = Field(default='PERCENT')  # 'PERCENT' atau 'NOMINAL'
    discount_percent: int = Field(default=0, ge=0, le=100)
    discount_nominal: int = Field(default=0, ge=0)


class OrderCreate(BaseModel):
    items: List[OrderItemCreate]
    customer_id: UUID
    notes: Optional[str] = None
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None


class OrderItemResponse(BaseModel):
    id: UUID
    product_id: str
    nama_barang: Optional[str] = None
    qty: int
    harga_satuan: int = 0
    discount_type: str = 'PERCENT'
    discount_percent: int = 0
    discount_nominal: int = 0
    harga_setelah_diskon: int = 0
    subtotal: Optional[int] = None

    class Config:
        from_attributes = True


class OrderDiscountUpdateItem(BaseModel):
    item_id: UUID
    discount_type: str = Field(..., description="'PERCENT' atau 'NOMINAL'")
    discount_percent: int = Field(default=0, ge=0, le=100)
    discount_nominal: int = Field(default=0, ge=0)


class OrderDiscountUpdate(BaseModel):
    """Bulk update discount per item — dipakai admin untuk koreksi sebelum approve/reject."""
    items: List[OrderDiscountUpdateItem]


class OrderResponse(BaseModel):
    id: UUID
    sales_id: UUID
    customer_id: Optional[UUID] = None
    customer_name: Optional[str] = None
    sales_username: Optional[str] = None
    sales_nama: Optional[str] = None
    status: str
    notes: Optional[str] = None
    created_at: datetime
    expired_at: Optional[datetime]
    items: List[OrderItemResponse] = []
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None
    total_amount: Optional[int] = None
    total_discount: Optional[int] = None

    class Config:
        from_attributes = True


class OrderListResponse(BaseModel):
    id: UUID
    sales_id: UUID
    customer_id: Optional[UUID] = None
    customer_name: Optional[str] = None
    sales_username: Optional[str] = None
    sales_nama: Optional[str] = None
    status: str
    notes: Optional[str] = None
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
    sales_nama: Optional[str] = None
    customer_id: Optional[UUID] = None
    customer_name: Optional[str] = None
    status: str
    notes: Optional[str] = None
    created_at: datetime
    expired_at: Optional[datetime]
    items: List[OrderItemResponse] = []
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None
    total_amount: Optional[int] = None
    total_discount: Optional[int] = None

    class Config:
        from_attributes = True


class OrderStatusUpdate(BaseModel):
    status: str


# ==================== CUSTOMERS ====================

class CustomerBase(BaseModel):
    kode: Optional[str] = Field(None, max_length=50)
    nama_toko: str = Field(..., min_length=1, max_length=200)
    alamat: Optional[str] = None


class CustomerCreate(CustomerBase):
    pass


class CustomerUpdate(BaseModel):
    nama_toko: Optional[str] = None
    alamat: Optional[str] = None


class CustomerResponse(CustomerBase):
    id: UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CustomerAssignmentRequest(BaseModel):
    sales_ids: List[UUID]


class SalesAssignmentResponse(BaseModel):
    sales_id: UUID
    sales_username: Optional[str] = None
    sales_nama: Optional[str] = None
    assigned_at: datetime


class SalesUserResponse(BaseModel):
    id: UUID
    username: str
    nama: Optional[str] = None
    role: str

    class Config:
        from_attributes = True


# ==================== SALES STATS ====================

class SalesStatsResponse(BaseModel):
    omset_hari_ini: int
    pending_count: int
    selesai_bulan_ini_count: int
    selesai_bulan_ini_total: int


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


class ImportLogResponse(BaseModel):
    id: UUID
    username: Optional[str]
    total_rows: int
    inserted: int
    updated: int
    skipped: int
    file_name: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

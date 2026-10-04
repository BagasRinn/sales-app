from pydantic import BaseModel, Field, field_validator, model_validator
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
    CANCELLED = "CANCELLED"
    # EXPIRED dihapus: logika expiration sudah tidak dipakai, tidak ada cron
    # job yang set status ke EXPIRED, dan DB tidak pernah mencatat status ini.


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


class ChangePasswordRequest(BaseModel):
    """Body untuk POST /auth/change-password — ganti password user sendiri."""
    old_password: str = Field(..., min_length=1, max_length=72)
    new_password: str = Field(..., min_length=6, max_length=72)


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
    order_type: Optional[str] = None  # 'REGULER' atau '4P', default REGULER


class ProductCreate(ProductBase):
    stok_sistem: int = 0
    stok_booking: int = 0
    kategori: Optional[str] = None
    satuan: Optional[str] = None
    order_type: str = 'REGULER'


class ProductUpdateStock(BaseModel):
    stok_sistem: int = Field(..., ge=0, description="Nilai stok_sistem baru")


class ProductUpdate(BaseModel):
    """Partial update untuk produk — admin only.
    Semua field opsional, hanya yang dikirim yang berubah.
    Dipakai untuk set kategori/satuan/nama_supplier/order_type."""
    kategori: Optional[str] = None
    satuan: Optional[str] = None
    nama_supplier: Optional[str] = None
    order_type: Optional[str] = None  # 'REGULER' atau '4P'


class ProductResponse(BaseModel):
    id: str
    nama_barang: str
    harga: int
    stok_sistem: int
    stok_booking: int
    # Default 0 supaya response lama (sebelum app redeploy) tidak break Pydantic
    # validation. Setelah deploy, backend selalu mengirim nilai real.
    stok_diterima: int = 0
    stok_tersedia: int
    perlu_ditinjau: Optional[bool] = None
    kategori: Optional[str] = None
    satuan: Optional[str] = None
    nama_supplier: Optional[str] = None
    order_type: str = 'REGULER'

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
    # --- Discount Layer 1 ---
    discount_type: str = Field(default='PERCENT')  # 'PERCENT' atau 'NOMINAL'
    discount_percent: int = Field(default=0, ge=0, le=100)
    discount_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 2 ---
    discount2_type: str = Field(default='PERCENT')
    discount2_percent: int = Field(default=0, ge=0, le=100)
    discount2_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 3 ---
    discount3_type: str = Field(default='PERCENT')
    discount3_percent: int = Field(default=0, ge=0, le=100)
    discount3_nominal: int = Field(default=0, ge=0)


class OrderCreate(BaseModel):
    items: List[OrderItemCreate]
    customer_id: UUID
    notes: Optional[str] = None
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None
    order_type: str = Field(default='REGULER')  # 'REGULER' atau '4P'
    invoice_number: Optional[str] = Field(None, max_length=50)


class OrderItemResponse(BaseModel):
    id: UUID
    product_id: str
    nama_barang: Optional[str] = None
    qty: int
    harga_satuan: int = 0
    # --- Discount Layer 1 ---
    discount_type: str = 'PERCENT'
    discount_percent: int = 0
    discount_nominal: int = 0
    # --- Discount Layer 2 ---
    discount2_type: str = 'PERCENT'
    discount2_percent: int = 0
    discount2_nominal: int = 0
    # --- Discount Layer 3 ---
    discount3_type: str = 'PERCENT'
    discount3_percent: int = 0
    discount3_nominal: int = 0
    # --- Derived ---
    harga_setelah_diskon: int = 0
    subtotal: Optional[int] = None

    class Config:
        from_attributes = True


class OrderDiscountUpdateItem(BaseModel):
    item_id: UUID
    # --- Discount Layer 1 ---
    discount_type: str = Field(..., description="'PERCENT' atau 'NOMINAL'")
    discount_percent: int = Field(default=0, ge=0, le=100)
    discount_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 2 ---
    discount2_type: str = Field(default='PERCENT')
    discount2_percent: int = Field(default=0, ge=0, le=100)
    discount2_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 3 ---
    discount3_type: str = Field(default='PERCENT')
    discount3_percent: int = Field(default=0, ge=0, le=100)
    discount3_nominal: int = Field(default=0, ge=0)


class OrderDiscountUpdate(BaseModel):
    """Bulk update discount per item — admin only."""
    items: List[OrderDiscountUpdateItem]


class CancelItemEntry(BaseModel):
    product_id: str
    qty: int = Field(..., ge=1)
    reason: str = Field(..., min_length=3)


class CancelItemsRequest(BaseModel):
    items: List[CancelItemEntry]


class CancelledItemResponse(BaseModel):
    product_id: str
    # Snapshot nama barang saat cancel — supaya UI tidak harus lookup ulang ke
    # tabel products. Null kalau produk sudah dihapus setelah cancel.
    nama_barang: Optional[str] = None
    qty: int
    reason: str


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
    items: List[OrderItemResponse] = []
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None
    total_amount: Optional[int] = None
    total_discount: Optional[int] = None
    order_type: str = 'REGULER'
    cancelled_items: Optional[List[CancelledItemResponse]] = None
    reject_reason: Optional[str] = None
    invoice_number: Optional[str] = None

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
    items: List[OrderItemResponse] = []
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None
    total_amount: Optional[int] = None
    total_discount: Optional[int] = None
    order_type: str = 'REGULER'
    invoice_number: Optional[str] = None

    class Config:
        from_attributes = True


class OrderStatusUpdate(BaseModel):
    status: str


class OrderReject(BaseModel):
    """Body untuk POST /orders/{order_id}/reject — admin bisa kasih alasan penolakan."""
    reject_reason: Optional[str] = Field(None, max_length=500)


# ==================== CUSTOMERS ====================

class CustomerBase(BaseModel):
    kode: Optional[str] = Field(None, max_length=50)
    nama_toko: str = Field(..., min_length=1, max_length=200)
    # alamat wajib: identitas toko = (nama_toko, alamat) — boleh ada dua toko
    # dengan nama sama selama alamat beda, dan sebaliknya.
    alamat: str = Field(..., min_length=1, max_length=500)


class CustomerCreate(CustomerBase):
    pass


class CustomerUpdate(BaseModel):
    nama_toko: Optional[str] = None
    alamat: Optional[str] = None
    kode_area: Optional[str] = None


class CustomerAssignmentsPut(BaseModel):
    """PUT body: replace the full set of sales assigned to a customer.
    Empty list = unassign everyone (backward-compat visible-to-all state)."""
    sales_ids: List[UUID] = Field(default_factory=list)


class SalesAssignmentItem(BaseModel):
    sales_id: UUID
    sales_username: Optional[str] = None
    sales_nama: Optional[str] = None
    assigned_at: datetime


class AreaAssignmentsPut(BaseModel):
    """PUT body: replace full set of sales assigned to a kode_area.
    Empty list = unassign semua sales dari area ini (customer di area
    kembali visible-to-all)."""
    sales_ids: List[UUID] = Field(default_factory=list)


class AreaAssignmentListItem(BaseModel):
    """Response untuk GET /area-assignments — list per-area dengan sales assigned."""
    kode_area: str
    sales: List[SalesAssignmentItem] = Field(default_factory=list)


class CustomerResponse(CustomerBase):
    id: UUID
    # Pengelompokan per area/rayon. Optional — legacy customer bisa null.
    kode_area: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    class Config:
        from_attributes = True


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
    nama: Optional[str]
    import_type: str = "PRODUCT"
    total_rows: int
    inserted: int
    updated: int
    skipped: int
    file_name: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ==================== CUSTOMER REGISTRATION SUBMISSIONS ====================

class CustomerSubmissionCreate(BaseModel):
    """Payload dari mobile saat sales submit pengajuan customer baru.
    sales_id otomatis dari token, tidak perlu di payload.

    Semua field wajib diisi oleh sales (kecuali key_account_ref_id).
    tipe_pembayaran wajib dipilih — KREDIT harus disertai jangka_kredit & batas_kredit.
    """
    # Section 1: Identitas
    nama_langganan: str = Field(..., min_length=1, max_length=200)
    nomor_id_ktp: Optional[str] = Field(None, max_length=50)
    alamat_ktp: Optional[str] = None
    nama_kontak_pemilik: str = Field(..., min_length=1, max_length=200)
    telpon_hp: str = Field(..., min_length=1, max_length=50)
    alamat_kirim: str = Field(..., min_length=1)
    propinsi: str = Field(..., min_length=1, max_length=100)
    kecamatan: str = Field(..., min_length=1, max_length=100)
    kota: str = Field(..., min_length=1, max_length=100)
    kelurahan: str = Field(..., min_length=1, max_length=100)
    area_route: Optional[str] = Field(None, max_length=100)
    tipe_langganan: str = Field(..., min_length=1, max_length=50)
    # Section 2: Tipe Pembayaran
    tipe_pembayaran: str = Field(..., min_length=1, max_length=20)
    nama_pasar: Optional[str] = Field(None, max_length=200)
    jangka_kredit_hari: Optional[int] = Field(
        None,
        description="Wajib diisi jika tipe_pembayaran=KREDIT. Jumlah hari plazo."
    )
    # Section 3: Batas Kredit
    batas_kredit_rupiah: Optional[int] = Field(
        None,
        description="Wajib diisi jika tipe_pembayaran=KREDIT. Batas kredit dalam IDR."
    )
    # Section 4: Channel
    channel_kategori: str = Field(..., min_length=1, max_length=50)
    # Section 5: Salesman
    key_account_ref_id: Optional[str] = Field(None, max_length=50)  # satu-satunya field opsional
    cluster_langganan: Optional[str] = Field(None, max_length=100)
    kode_salesman: str = Field(..., min_length=1, max_length=50)
    nama_salesman: str = Field(..., min_length=1, max_length=200)
    siklus_kunjungan: str = Field(..., min_length=1, max_length=100)
    hari_kunjungan: str = Field(..., min_length=1, max_length=50)
    # Flag: kalau True, customer langsung dibuat saat submit (untuk flow "bareng order").
    bareng_order: bool = Field(default=False)

    @field_validator('tipe_pembayaran')
    @classmethod
    def validate_tipe_pembayaran(cls, v: str) -> str:
        if v not in ('TUNAI', 'KREDIT'):
            raise ValueError("tipe_pembayaran harus 'TUNAI' atau 'KREDIT'")
        return v

    @field_validator('jangka_kredit_hari', 'batas_kredit_rupiah')
    @classmethod
    def validate_kredit_fields(cls, v, info):
        return v

    @model_validator(mode='after')
    def validate_kredit_required_if_kredit(self):
        if self.tipe_pembayaran == 'KREDIT':
            if self.jangka_kredit_hari is None or self.jangka_kredit_hari <= 0:
                raise ValueError(
                    "jangka_kredit_hari wajib diisi dan harus > 0 jika tipe_pembayaran=KREDIT"
                )
            if self.batas_kredit_rupiah is None or self.batas_kredit_rupiah <= 0:
                raise ValueError(
                    "batas_kredit_rupiah wajib diisi dan harus > 0 jika tipe_pembayaran=KREDIT"
                )
        return self


class CustomerSubmissionApprove(BaseModel):
    """Body untuk approve submission. kode wajib (diinput admin manual),
    nama_toko & alamat opsional (default pakai value dari submission)."""
    kode: str = Field(..., min_length=1, max_length=50)
    nama_toko: Optional[str] = Field(None, min_length=1, max_length=200)
    alamat: Optional[str] = Field(None, min_length=1, max_length=500)


class CustomerSubmissionReject(BaseModel):
    """Body untuk reject submission. reject_reason opsional."""
    reject_reason: Optional[str] = None


class CustomerSubmissionResponse(BaseModel):
    id: UUID
    sales_id: UUID
    sales_nama: Optional[str] = None
    sales_username: Optional[str] = None
    status: str
    reject_reason: Optional[str] = None
    approved_customer_id: Optional[UUID] = None
    # customer_id yang langsung dibuat saat bareng_order=True
    bareng_customer_id: Optional[UUID] = None
    reviewed_by: Optional[UUID] = None
    reviewed_by_nama: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    # Form fields
    nama_langganan: str
    nomor_id_ktp: Optional[str] = None
    alamat_ktp: Optional[str] = None
    nama_kontak_pemilik: Optional[str] = None
    telpon_hp: Optional[str] = None
    alamat_kirim: Optional[str] = None
    propinsi: Optional[str] = None
    kecamatan: Optional[str] = None
    kota: Optional[str] = None
    kelurahan: Optional[str] = None
    area_route: Optional[str] = None
    tipe_langganan: Optional[str] = None
    tipe_pembayaran: Optional[str] = None
    nama_pasar: Optional[str] = None
    jangka_kredit_hari: Optional[int] = None
    batas_kredit_rupiah: Optional[int] = None
    channel_kategori: Optional[str] = None
    key_account_ref_id: Optional[str] = None
    cluster_langganan: Optional[str] = None
    kode_salesman: Optional[str] = None
    nama_salesman: Optional[str] = None
    siklus_kunjungan: Optional[str] = None
    hari_kunjungan: Optional[str] = None

    class Config:
        from_attributes = True


# ==================== SALES TARGETS ====================

class SalesTargetUpdate(BaseModel):
    """Body untuk PUT /sales-targets/{user_id}."""
    period: str = Field(..., description="Periode dalam format YYYY-MM")
    target_type: str = Field(..., description="'ORDER_COUNT' atau 'REVENUE'")
    target_value: int = Field(..., ge=0, description="Nilai target")
    incentive_amount: int = Field(default=0, ge=0, description="Bonus jika target tercapai")


class SalesTargetResponse(BaseModel):
    id: UUID
    user_id: UUID
    period: str
    target_type: str
    target_value: int
    incentive_amount: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ==================== SALES PERFORMANCE ====================

class SalesPerformanceItem(BaseModel):
    user_id: UUID
    username: str
    nama: Optional[str] = None
    order_count: int = 0
    revenue: int = 0
    submission_count: int = 0

    class Config:
        from_attributes = True


class SalesPerformanceResponse(BaseModel):
    sales: List[SalesPerformanceItem]


# ==================== BULLETINS ====================

class BulletinCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    pdf_url: Optional[str] = Field(None, max_length=500)
    expire_at: Optional[datetime] = None


class BulletinUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    pdf_url: Optional[str] = Field(None, max_length=500)
    expire_at: Optional[datetime] = None


class BulletinResponse(BaseModel):
    id: UUID
    title: str
    description: Optional[str] = None
    pdf_url: Optional[str] = None
    expire_at: Optional[datetime] = None
    created_at: datetime
    is_read: bool = False  # sudah di-dismiss oleh sales ini atau belum

    class Config:
        from_attributes = True

from pydantic import BaseModel, Field, field_validator, model_validator
from uuid import UUID
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from enum import Enum


# Backend menyimpan semua timestamp sebagai UTC di Postgres
# (DateTime(timezone=True)). Saat di-read, SQLAlchemy strip tzinfo
# sehingga Pydantic serialize tanpa suffix. Selain itu, business timezone
# aplikasi ini adalah WITA (UTC+8) — semua datetime yang dikembalikan ke
# client (Flutter mobile + web) harus dalam WITA supaya frontend cukup
# parse + format tanpa konversi timezone sendiri.
WITA = timezone(timedelta(hours=8))


class BaseSchema(BaseModel):
    """Base untuk semua response schema.

    Validator ini: (1) re-attach tzinfo=UTC kalau datetime naive (dari
    SQLAlchemy), lalu (2) convert ke WITA. Hasilnya ISO string selalu
    pakai suffix "+08:00", frontend tidak perlu konversi lagi.
    """

    @field_validator("*", mode="before")
    @classmethod
    def _to_wita_datetime(cls, v):
        if isinstance(v, datetime):
            if v.tzinfo is None:
                v = v.replace(tzinfo=timezone.utc)
            v = v.astimezone(WITA)
        return v


class UserRole(str, Enum):
    ADMIN = "ADMIN"
    MANAGER = "MANAGER"  # global — branch=NULL
    SUPERVISOR = "SUPERVISOR"  # branch-scoped (formerly MANAGER)
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

class UserCreate(BaseSchema):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6, max_length=72)
    role: str = Field(..., description="ADMIN, SUPERVISOR, MANAGER, atau SALES")
    nama: Optional[str] = Field(None, max_length=100)
    branch: Optional[str] = Field(None, description="Branch code. Required for ADMIN/SUPERVISOR/SALES. Omit or null for global MANAGER.")


class UserUpdate(BaseSchema):
    """Edit user — semua field opsional, hanya yang dikirim yang berubah."""
    nama: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = Field(None, min_length=6, max_length=72)
    is_active: Optional[bool] = None
    branch: Optional[str] = Field(None, description="Branch code. Null = global MANAGER.")


class ChangePasswordRequest(BaseSchema):
    """Body untuk POST /auth/change-password — ganti password user sendiri."""
    old_password: str = Field(..., min_length=1, max_length=72)
    new_password: str = Field(..., min_length=6, max_length=72)


class UserResponse(BaseSchema):
    id: UUID
    username: str
    nama: Optional[str] = None
    role: str
    branch: Optional[str] = None
    is_active: bool = True
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserLogin(BaseSchema):
    username: str
    password: str


class Token(BaseSchema):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    username: Optional[str] = None
    nama: Optional[str] = None
    role: Optional[str] = None
    branch: Optional[str] = None  # NULL for global MANAGER
    branch_nama: Optional[str] = None  # display label for branch
    is_active: Optional[bool] = None


class RefreshTokenRequest(BaseSchema):
    refresh_token: str


# ==================== PRODUCTS ====================

class ProductBase(BaseSchema):
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


class ProductUpdateStock(BaseSchema):
    stok_sistem: int = Field(..., ge=0, description="Nilai stok_sistem baru")


class ProductUpdate(BaseSchema):
    """Partial update untuk produk — admin only.
    Semua field opsional, hanya yang dikirim yang berubah.
    Dipakai untuk set kategori/satuan/nama_supplier/order_type."""
    kategori: Optional[str] = None
    satuan: Optional[str] = None
    nama_supplier: Optional[str] = None
    order_type: Optional[str] = None  # 'REGULER' atau '4P'


class ProductResponse(BaseSchema):
    id: str
    branch: Optional[str] = None
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


class SyncErrorItem(BaseSchema):
    row: int
    sku: str
    reason: str


class SyncResultResponse(BaseSchema):
    success: bool
    total_rows: int
    inserted: int
    updated: int
    skipped: int
    errors: List[SyncErrorItem]
    needs_review: bool = False


# ==================== ORDERS ====================

class OrderItemCreate(BaseSchema):
    product_id: str
    qty: int = Field(..., gt=0)
    # --- Discount Layer 1 ---
    discount_type: str = Field(default='PERCENT')  # 'PERCENT' atau 'NOMINAL'
    discount_percent: float = Field(default=0.0, ge=0.0, le=100.0)
    discount_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 2 ---
    discount2_type: str = Field(default='PERCENT')
    discount2_percent: float = Field(default=0.0, ge=0.0, le=100.0)
    discount2_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 3 ---
    discount3_type: str = Field(default='PERCENT')
    discount3_percent: float = Field(default=0.0, ge=0.0, le=100.0)
    discount3_nominal: int = Field(default=0, ge=0)


class OrderCreate(BaseSchema):
    items: List[OrderItemCreate]
    customer_id: UUID
    notes: Optional[str] = None
    store_name: Optional[str] = None
    store_contact: Optional[str] = None
    store_address: Optional[str] = None
    order_type: str = Field(default='REGULER')  # 'REGULER' atau '4P'
    invoice_number: Optional[str] = Field(None, max_length=50)


class OrderItemResponse(BaseSchema):
    id: UUID
    product_id: str
    nama_barang: Optional[str] = None
    qty: int
    harga_satuan: int = 0
    # --- Discount Layer 1 ---
    discount_type: str = 'PERCENT'
    discount_percent: float = 0.0
    discount_nominal: int = 0
    # --- Discount Layer 2 ---
    discount2_type: str = 'PERCENT'
    discount2_percent: float = 0.0
    discount2_nominal: int = 0
    # --- Discount Layer 3 ---
    discount3_type: str = 'PERCENT'
    discount3_percent: float = 0.0
    discount3_nominal: int = 0
    # --- Derived ---
    harga_setelah_diskon: int = 0
    subtotal: Optional[int] = None

    class Config:
        from_attributes = True


class OrderDiscountUpdateItem(BaseSchema):
    item_id: UUID
    # --- Discount Layer 1 ---
    discount_type: str = Field(..., description="'PERCENT' atau 'NOMINAL'")
    discount_percent: float = Field(default=0.0, ge=0.0, le=100.0)
    discount_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 2 ---
    discount2_type: str = Field(default='PERCENT')
    discount2_percent: float = Field(default=0.0, ge=0.0, le=100.0)
    discount2_nominal: int = Field(default=0, ge=0)
    # --- Discount Layer 3 ---
    discount3_type: str = Field(default='PERCENT')
    discount3_percent: float = Field(default=0.0, ge=0.0, le=100.0)
    discount3_nominal: int = Field(default=0, ge=0)


class OrderDiscountUpdate(BaseSchema):
    """Bulk update discount per item — admin only."""
    items: List[OrderDiscountUpdateItem]


class CancelItemEntry(BaseSchema):
    item_id: UUID
    qty: int = Field(..., ge=1)
    reason: str = Field(..., min_length=3)


class CancelItemsRequest(BaseSchema):
    items: List[CancelItemEntry]


class CancelledItemResponse(BaseSchema):
    product_id: str
    # Snapshot nama barang saat cancel — supaya UI tidak harus lookup ulang ke
    # tabel products. Null kalau produk sudah dihapus setelah cancel.
    nama_barang: Optional[str] = None
    qty: int
    # Snapshot harga saat cancel — supaya admin bisa lihat impact finansial
    # dari item yang dibatalkan. Null/0 kalau produk sudah dihapus.
    harga_satuan: Optional[int] = None
    subtotal: Optional[int] = None
    reason: str


class OrderResponse(BaseSchema):
    id: UUID
    branch: Optional[str] = None
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


class OrderListResponse(BaseSchema):
    id: UUID
    branch: Optional[str] = None
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


class OrderListWithItemsResponse(BaseSchema):
    id: UUID
    branch: Optional[str] = None
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


class OrderStatusUpdate(BaseSchema):
    status: str


class OrderReject(BaseSchema):
    """Body untuk POST /orders/{order_id}/reject — admin bisa kasih alasan penolakan."""
    reject_reason: Optional[str] = Field(None, max_length=500)


# ==================== CUSTOMERS ====================

class CustomerBase(BaseSchema):
    kode: Optional[str] = Field(None, max_length=50)
    nama_toko: str = Field(..., min_length=1, max_length=200)
    # alamat wajib: identitas toko = (nama_toko, alamat) — boleh ada dua toko
    # dengan nama sama selama alamat beda, dan sebaliknya.
    alamat: str = Field(..., min_length=1, max_length=500)


class CustomerCreate(CustomerBase):
    pass


class CustomerUpdate(BaseSchema):
    nama_toko: Optional[str] = None
    alamat: Optional[str] = None
    kode_area: Optional[str] = None


class CustomerAssignmentsPut(BaseSchema):
    """PUT body: replace the full set of sales assigned to a customer.
    Empty list = unassign everyone (backward-compat visible-to-all state)."""
    sales_ids: List[UUID] = Field(default_factory=list)


class SalesAssignmentItem(BaseSchema):
    sales_id: UUID
    sales_username: Optional[str] = None
    sales_nama: Optional[str] = None
    assigned_at: datetime


class AreaAssignmentsPut(BaseSchema):
    """PUT body: replace full set of sales assigned to a kode_area.
    Empty list = unassign semua sales dari area ini (customer di area
    kembali visible-to-all)."""
    sales_ids: List[UUID] = Field(default_factory=list)


class AreaAssignmentListItem(BaseSchema):
    """Response untuk GET /area-assignments — list per-area dengan sales assigned."""
    kode_area: str
    sales: List[SalesAssignmentItem] = Field(default_factory=list)


class CustomerResponse(CustomerBase):
    id: UUID
    branch: Optional[str] = None
    # Pengelompokan per area/rayon. Optional — legacy customer bisa null.
    kode_area: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class KodeAreaListResponse(BaseSchema):
    """List distinct kode_area dari customers — sumber dropdown 'Kode Area'
    di mobile submission form. Sales boleh membuat kode_area baru yang
    belum ada di list (free-text fallback di form)."""
    items: List[str] = Field(default_factory=list)


class SalesUserResponse(BaseSchema):
    id: UUID
    username: str
    nama: Optional[str] = None
    role: str

    class Config:
        from_attributes = True


# ==================== SALES STATS ====================

class SalesStatsResponse(BaseSchema):
    omset_hari_ini: int
    pending_count: int
    selesai_bulan_ini_count: int
    selesai_bulan_ini_total: int


# ==================== STOCK LOG ====================

class StokLogResponse(BaseSchema):
    id: UUID
    branch: Optional[str] = None
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


class ImportLogResponse(BaseSchema):
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

class CustomerSubmissionCreate(BaseSchema):
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
    kode_area: Optional[str] = Field(None, max_length=50)
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
    kode_salesman: Optional[str] = Field(None, max_length=50)
    nama_salesman: Optional[str] = Field(None, max_length=200)
    siklus_kunjungan: str = Field(..., min_length=1, max_length=100)
    hari_kunjungan: str = Field(..., min_length=1, max_length=50)
    # Flag: kalau True, customer langsung dibuat saat submit (untuk flow "bareng order").
    bareng_order: bool = Field(default=False)
    # Order type untuk bareng_order flow. Items dipilih di OrderFlowScreen setelah submit.
    order_type: Optional[str] = Field(
        default="REGULER",
        description="'REGULER' or '4P'. Only used when bareng_order=True."
    )

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

    @model_validator(mode='after')
    def validate_bareng_order_items(self):
        # Sejak UI dipisah (Oct 2026), sales pilih barang di OrderFlowScreen
        # setelah submit, bukan di form customer. order_items tidak dikirim
        # dari Flutter lagi — backend yang handle order kosong.
        return self


class CustomerSubmissionApprove(BaseSchema):
    """Body untuk approve submission. kode wajib (diinput admin manual),
    nama_toko & alamat opsional (default pakai value dari submission)."""
    kode: str = Field(..., min_length=1, max_length=50)
    nama_toko: Optional[str] = Field(None, min_length=1, max_length=200)
    alamat: Optional[str] = Field(None, min_length=1, max_length=500)


class CustomerSubmissionReject(BaseSchema):
    """Body untuk reject submission. reject_reason opsional."""
    reject_reason: Optional[str] = None


class CustomerSubmissionCancelRequest(BaseSchema):
    """Body for POST /customer-submissions/{id}/cancel. Empty body."""
    pass


class CustomerSubmissionCancelResponse(BaseSchema):
    message: str
    submission_id: UUID
    status: str = "CANCELLED"


class CustomerSubmissionResponse(BaseSchema):
    id: UUID
    branch: Optional[str] = None
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
    kode_area: Optional[str] = None
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
    order: Optional["OrderResponse"] = Field(default=None)

    class Config:
        from_attributes = True


# ==================== SALES TARGETS ====================

class SalesTargetUpdate(BaseSchema):
    """Body untuk PUT /sales-targets/{user_id}."""
    period: str = Field(..., description="Periode dalam format YYYY-MM")
    target_type: str = Field(..., description="'ORDER_COUNT' atau 'REVENUE'")
    target_value: int = Field(..., ge=0, description="Nilai target")
    incentive_amount: int = Field(default=0, ge=0, description="Bonus jika target tercapai")


class SalesTargetResponse(BaseSchema):
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

class SalesPerformanceItem(BaseSchema):
    user_id: UUID
    username: str
    nama: Optional[str] = None
    order_count: int = 0
    revenue: int = 0
    submission_count: int = 0

    class Config:
        from_attributes = True


class SalesPerformanceResponse(BaseSchema):
    sales: List[SalesPerformanceItem]


class SalesPerformanceDashboardItem(BaseSchema):
    """Per-sales breakdown for manager dashboard card."""
    user_id: UUID
    username: str
    nama: Optional[str] = None
    # APPROVED — MTD (month-to-date) + Today
    approved_mtd_count: int = 0
    approved_mtd_revenue: int = 0
    approved_today_count: int = 0
    approved_today_revenue: int = 0
    # PENDING — MTD + Today
    pending_mtd_count: int = 0
    pending_mtd_revenue: int = 0
    pending_today_count: int = 0
    pending_today_revenue: int = 0
    # REJECTED — MTD + Today
    rejected_mtd_count: int = 0
    rejected_mtd_revenue: int = 0
    rejected_today_count: int = 0
    rejected_today_revenue: int = 0

    @property
    def display_name(self) -> str:
        return self.nama if (self.nama and self.nama.strip()) else self.username


class SalesPerformanceDashboardResponse(BaseSchema):
    sales: List[SalesPerformanceDashboardItem]


# ==================== BULLETINS ====================

class BulletinCreate(BaseSchema):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    pdf_url: Optional[str] = Field(None, max_length=500)
    expire_at: Optional[datetime] = None


class BulletinUpdate(BaseSchema):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    pdf_url: Optional[str] = Field(None, max_length=500)
    expire_at: Optional[datetime] = None


class BulletinResponse(BaseSchema):
    id: UUID
    branch: Optional[str] = None  # NULL = global bulletin
    title: str
    description: Optional[str] = None
    pdf_url: Optional[str] = None
    expire_at: Optional[datetime] = None
    created_at: datetime
    is_read: bool = False  # sudah di-dismiss oleh sales ini atau belum

    class Config:
        from_attributes = True


# ==================== CROSS-BRANCH REPORTS (global MANAGER only) ====================

class BranchSalesSummary(BaseSchema):
    branch: str
    branch_nama: str
    approved_count: int = 0
    approved_revenue: int = 0
    pending_count: int = 0
    customer_count: int = 0
    sales_count: int = 0


class CrossBranchSalesSummaryResponse(BaseSchema):
    branches: List[BranchSalesSummary]


class BranchStockSummary(BaseSchema):
    branch: str
    branch_nama: str
    sku_count: int = 0
    total_stock_value: int = 0
    low_stock_count: int = 0


class CrossBranchStockSummaryResponse(BaseSchema):
    branches: List[BranchStockSummary]

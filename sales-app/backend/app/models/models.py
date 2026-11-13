import uuid
from sqlalchemy import Column, Integer, String, ForeignKey, ForeignKeyConstraint, Date, DateTime, Index, Boolean, Text, BigInteger, JSON, Numeric, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy.sql import func

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), unique=True, index=True)
    password_hash = Column(String)
    role = Column(String(10))
    nama = Column(String(100), nullable=True)
    # Branch scoping: ADMIN/SUPERVISOR/SALES = branch-scoped; MANAGER = NULL (global).
    # Nullable because global MANAGER has no branch.
    branch = Column(String(20), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    token_version = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    orders = relationship("Order", back_populates="sales")
    # Penugasan outlet: 1 sales bisa pegang banyak customer.
    # `foreign_keys` pakai string reference karena User didefinisikan sebelum
    # CustomerAssignment. Tanpa ini SQLAlchemy tidak bisa auto-detect join
    # condition (ada 2 FK ke users: sales_id + assigned_by).
    customer_assignments = relationship(
        "CustomerAssignment",
        back_populates="sales",
        cascade="all, delete-orphan",
        foreign_keys="CustomerAssignment.sales_id",
    )


class Branch(Base):
    """Single source of truth for branch codes & display labels.

    Replaces the hardcoded BRANCH_CODES / BRANCH_LABELS in app/core/branch.py.
    Other tables (users, products, customers, orders, bulletins, etc.) hold a
    VARCHAR(20) `branch` column with FK to this table (added via migration
    migrate_2026_10_10_02).

    Note: there is no `relationship` defined here because existing `branch`
    columns are plain `String` (not `ForeignKey`). Endpoints that need
    `branch_nama` do manual `outerjoin(Branch, Branch.code == ...branch_col)`.
    """
    __tablename__ = "branches"
    __table_args__ = (
        Index("ix_branches_is_active", "is_active"),
    )

    code = Column(String(20), primary_key=True)
    nama = Column(String(100), nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class Product(Base):
    __tablename__ = "products"

    # Composite PK: (branch, id) — same SKU can exist in different branches.
    id = Column(String, primary_key=True)
    branch = Column(String(20), primary_key=True, index=True)
    nama_barang = Column(String, index=True)
    harga = Column(Integer)
    stok_sistem = Column(Integer, default=0)
    stok_booking = Column(Integer, default=0)
    # Qty yang sudah di-approve (barang sudah dikirim/diterima).
    # Ditambah saat admin approve PENDING order; tidak pernah di-decrement
    # oleh flow order normal (sync Excel & backfill DRAFT lama boleh zero-kan).
    # Rumus: stok_tersedia = max(0, stok_sistem - stok_booking - stok_diterima).
    stok_diterima = Column(Integer, default=0, nullable=False)
    kategori = Column(String, nullable=True)
    satuan = Column(String, nullable=True)
    nama_supplier = Column(String, nullable=True)
    # Tipe order: 'REGULER' atau '4P'. Default REGULER — supervisor yg
    # nanti set 4P per produk via admin web. Dipakai buat filter order flow
    # mobile + validasi item harus cocok dgn order.order_type.
    order_type = Column(String(10), nullable=False, default='REGULER')


class Customer(Base):
    __tablename__ = "customers"
    __table_args__ = (
        # Customer identity = (branch, kode, kode_area). Same pattern as Product (id, branch).
        # kode/kode_area may be NULL; multiple NULLs allowed by Postgres UNIQUE index.
        # Satu kode boleh di branch + kode_area berbeda (mis. P0001 di
        # BANJARMASIN/MULIA1 dan P0001 di BANJARMASIN/MULIA2 = 2 customer beda).
        UniqueConstraint("branch", "kode", "kode_area", name="uq_customers_branch_kode_kode_area"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Branch scoping: kode unique within a branch, may repeat across branches.
    branch = Column(String(20), nullable=False, index=True)
    kode = Column(String(50), nullable=True, index=True)
    nama_toko = Column(String(200), nullable=False, index=True)
    alamat = Column(String(500), nullable=True)
    # Pengelompokan customer per area/rayon. Default assignment sales pakai
    # kolom ini — manager assign 1 sales ke "MULIA2" → semua customer dengan
    # kode_area='MULIA2' otomatis dapat coverage. Field deskriptif saja,
    # bukan bagian dari identity (lihat UniqueConstraint di atas).
    kode_area = Column(String(50), nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    orders = relationship("Order", back_populates="customer")
    # Penugasan outlet: 1 customer bisa ditugaskan ke banyak sales.
    assignments = relationship(
        "CustomerAssignment", back_populates="customer", cascade="all, delete-orphan"
    )


class CustomerAssignment(Base):
    """Junction table untuk many-to-many sales ↔ customer.
    sales_id mengarah ke user dengan role=SALES; customer_id mengarah ke customer master.
    Customer dengan 0 row di sini = 'unassigned' = visible ke semua sales (backward-compat).
    """
    __tablename__ = "customer_assignments"

    customer_id = Column(
        UUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="CASCADE"),
        primary_key=True,
    )
    sales_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    assigned_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    # Audit: siapa manager yang assign. ON DELETE SET NULL supaya assignment
    # tidak hilang kalau manager user di-delete.
    assigned_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    customer = relationship("Customer", back_populates="assignments")
    # `foreign_keys` wajib karena tabel ini punya 2 FK ke users
    # (sales_id + assigned_by). Tanpa ini SQLAlchemy tidak bisa auto-detect
    # join condition untuk relationship User.customer_assignments.
    sales = relationship(
        "User", back_populates="customer_assignments", foreign_keys=[sales_id]
    )


class AreaAssignment(Base):
    """Sales coverage by area — default assignment unit.
    Sales di-assign ke kode_area tertentu; semua customer dengan kode_area yang
    sama otomatis visible (kecuali ada per-customer override di CustomerAssignment).

    kode_area adalah VARCHAR (bukan FK ke tabel area) — fleksibel, area bisa
    di-create on-the-fly via import excel atau manual edit.

    Identity = (branch, kode_area, sales_id) — same pattern sebagai Product
    (id, branch) dan Customer (branch, kode). Area bernama sama (mis. MULIA1)
    BOLEH di branch berbeda karena PK composite mencakup branch.
    """
    __tablename__ = "area_assignments"

    kode_area = Column(String(50), primary_key=True)
    sales_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    # Branch wajib — di-tag dari JWT user saat assignment dibuat.
    branch = Column(String(20), primary_key=True, nullable=False, index=True)
    assigned_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    assigned_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Lihat komentar di CustomerAssignment.sales untuk kenapa foreign_keys
    # wajib di sini juga — assigned_by juga FK ke users.
    sales = relationship(
        "User", foreign_keys=[sales_id]
    )


class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Branch scoping: set to sales user's branch at order creation time.
    branch = Column(String(20), nullable=False, index=True)
    sales_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=True)
    status = Column(String(20), default="DRAFT")
    notes = Column(String(1000), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    store_name = Column(String(200), nullable=True)
    store_contact = Column(String(50), nullable=True)
    store_address = Column(String(500), nullable=True)
    # Tipe order: 'REGULER' atau '4P'. Diset saat create order dari mobile.
    order_type = Column(String(10), nullable=False, default='REGULER')
    # Item yang dibatalkan oleh admin (bukan dihapus, tapi dicoret). Format:
    # [{"product_id": "...", "qty": 2, "reason": "Barang gudang rusak"}]
    cancelled_items = Column(JSON, nullable=True)
    # Alasan penolakan order oleh admin — sales bisa lihat di mobile.
    reject_reason = Column(Text, nullable=True)
    # Nomor invoice untuk tracking order dengan invoice yang sama.
    invoice_number = Column(String(50), nullable=True, index=True)
    # Idempotency key from client for duplicate prevention
    client_request_id = Column(String(128), nullable=True, index=True)
    # Order-level (global) discount — applied to total after item-level discounts
    order_discount_type = Column(String(10), default='PERCENT')  # 'PERCENT' atau 'NOMINAL'
    order_discount_nominal = Column(Integer, default=0)  # dalam IDR
    # Order-level (global) up price — applied to total before order-level discount
    order_up_price_type = Column(String(10), default='NOMINAL')  # 'PERCENT' atau 'NOMINAL'
    order_up_price_nominal = Column(Integer, default=0)  # dalam IDR

    # Satu-satunya deklarasi __table_args__ untuk tabel ini. Sebelumnya ada dua
    # blok (yang kedua menimpa yang pertama, sehingga index komposit di blok
    # pertama tidak pernah terdaftar di metadata). Penggabungan ini hanya
    # memengaruhi metadata SQLAlchemy — tidak mengubah tabel yang sudah ada,
    # karena create_all() melewati tabel yang sudah dibuat.
    __table_args__ = (
        Index("ix_orders_status", "status"),
        Index("ix_orders_created_at", "created_at"),
        Index("ix_orders_status_created_at", "status", "created_at"),
        Index("ix_orders_branch_status_created_at", "branch", "status", "created_at"),
        Index("ix_orders_sales_status_created", "sales_id", "status", "created_at"),
        Index("ix_orders_sales_id", "sales_id"),
        Index("ix_orders_customer_id", "customer_id"),
    )

    sales = relationship("User", back_populates="orders")
    customer = relationship("Customer", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", lazy="select")


class OrderItem(Base):
    __tablename__ = "order_items"
    __table_args__ = (
        ForeignKeyConstraint(["product_id", "branch"], ["products.id", "products.branch"]),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id = Column(UUID(as_uuid=True), ForeignKey("orders.id"))
    product_id = Column(String)
    branch = Column(String(20), nullable=False)  # branch diset saat item dibuat = branch dari parent Order
    qty = Column(Integer)

    # --- Discount Layer 1 (existing single discount, retained as layer 1) ---
    discount_percent = Column(Numeric(10, 4), default=0)  # dipakai kalau discount_type == 'PERCENT'
    discount_type = Column(String(10), default='PERCENT')  # 'PERCENT' atau 'NOMINAL'
    discount_nominal = Column(Integer, default=0)  # dipakai kalau discount_type == 'NOMINAL', dalam IDR

    # --- Discount Layer 2 (stacked setelah Layer 1, sequential) ---
    discount2_type = Column(String(10), default='PERCENT', nullable=False)
    discount2_percent = Column(Numeric(10, 4), default=0, nullable=False)
    discount2_nominal = Column(Integer, default=0, nullable=False)

    # --- Discount Layer 3 (stacked setelah Layer 2, sequential) ---
    discount3_type = Column(String(10), default='PERCENT', nullable=False)
    discount3_percent = Column(Numeric(10, 4), default=0, nullable=False)
    discount3_nominal = Column(Integer, default=0, nullable=False)

    # --- Up Price (1 layer, per-piece, applied to base sebelum diskon) ---
    up_price_type = Column(String(10), default='NOMINAL', nullable=False)  # 'PERCENT' atau 'NOMINAL'
    up_price_percent = Column(Numeric(10, 4), default=0, nullable=False)  # 0-100 kalau PERCENT
    up_price_nominal = Column(Integer, default=0, nullable=False)  # per-piece IDR kalau NOMINAL

    order = relationship("Order", back_populates="items")
    product = relationship("Product")


class StokLog(Base):
    __tablename__ = "stok_log"
    __table_args__ = (
        ForeignKeyConstraint(["product_id", "branch"], ["products.id", "products.branch"]),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Branch denormalized from product for branch-scoped audit trail.
    branch = Column(String(20), nullable=False, index=True)
    product_id = Column(String, index=True)
    sumber = Column(String(20))
    field_terdampak = Column(String(20))
    delta = Column(Integer)
    nilai_sebelum = Column(Integer)
    nilai_sesudah = Column(Integer)
    actor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    order_id = Column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class CustomerRegistrationSubmission(Base):
    """Pengajuan customer baru dari sales. Approve → bikin Customer baru dengan kode yg diinput admin."""
    __tablename__ = "customer_registration_submissions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Branch scoping: set to sales user's branch at submission time.
    branch = Column(String(20), nullable=False, index=True)
    sales_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    status = Column(String(20), nullable=False, default='PENDING')
    reject_reason = Column(Text, nullable=True)
    approved_customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=True)
    # Customer ID yang langsung dibuat saat submission dengan bareng_order=True.
    bareng_customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=True)
    reviewed_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())

    # Section 1: Identitas
    nama_langganan = Column(String(200), nullable=False)
    nomor_id_ktp = Column(String(50), nullable=True)
    alamat_ktp = Column(Text, nullable=True)
    nama_kontak_pemilik = Column(String(200), nullable=True)
    telpon_hp = Column(String(50), nullable=True)
    alamat_kirim = Column(Text, nullable=True)
    propinsi = Column(String(100), nullable=True)
    kecamatan = Column(String(100), nullable=True)
    kota = Column(String(100), nullable=True)
    kelurahan = Column(String(100), nullable=True)
    area_route = Column(String(100), nullable=True)
    # Mirrors customers.kode_area — grouping key untuk sales coverage.
    # Nullable: legacy rows stay NULL; approve flow copies this ke
    # customers.kode_area saat submission di-approve.
    kode_area = Column(String(50), nullable=True)
    tipe_langganan = Column(String(50), nullable=True)

    # Section 2: Tipe Pembayaran
    tipe_pembayaran = Column(String(20), nullable=True)
    nama_pasar = Column(String(200), nullable=True)
    jangka_kredit_hari = Column(Integer, nullable=True)

    # Section 3: Batas Kredit
    batas_kredit_rupiah = Column(BigInteger, nullable=True)

    # Section 4: Channel/Kategori
    channel_kategori = Column(String(50), nullable=True)

    # Section 5: Salesman
    key_account_ref_id = Column(String(50), nullable=True)
    cluster_langganan = Column(String(100), nullable=True)
    kode_salesman = Column(String(50), nullable=True)
    nama_salesman = Column(String(200), nullable=True)
    siklus_kunjungan = Column(String(100), nullable=True)
    hari_kunjungan = Column(String(50), nullable=True)


class SyncValidationError(Base):
    """Persisted validation errors from a sync run — used by GET /products/sync/errors."""
    __tablename__ = "sync_validation_errors"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    import_log_id = Column(UUID(as_uuid=True), ForeignKey("import_logs.id"), nullable=True)
    row_number = Column(Integer)
    sku = Column(String, nullable=True)
    reason = Column(String(255))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ImportLog(Base):
    """Tracks every Excel import run."""
    __tablename__ = "import_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, nullable=True)
    nama = Column(String, nullable=True)
    import_type = Column(String, nullable=False, default="PRODUCT")
    total_rows = Column(Integer, default=0)
    inserted = Column(Integer, default=0)
    updated = Column(Integer, default=0)
    skipped = Column(Integer, default=0)
    file_name = Column(String, nullable=True)
    # Branch dari JWT user yang melakukan import. Nullable untuk log lama
    # sebelum tagging ini; endpoint read treat NULL sebagai legacy-visible
    # (semua admin bisa lihat supaya histori tidak hilang). Tag dari
    # import_logs endpoint sudah filter by current_user.branch.
    branch = Column(String(20), nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DataPenjualanTarget(Base):
    """Monthly revenue targets used only by the imported-sales dashboard."""
    __tablename__ = "data_penjualan_targets"
    __table_args__ = (
        UniqueConstraint(
            "branch",
            "period",
            "target_type",
            "name_key",
            name="uq_data_penjualan_targets_scope_name",
        ),
        Index(
            "ix_data_penjualan_targets_lookup",
            "branch",
            "period",
            "target_type",
        ),
        Index(
            "ix_data_penjualan_targets_period_branch",
            "period",
            "branch",
            "target_type",
        ),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    branch = Column(String(20), nullable=False)
    period = Column(String(7), nullable=False)
    target_type = Column(String(10), nullable=False)
    name = Column(String(200), nullable=False)
    name_key = Column(String(200), nullable=False)
    target_value = Column(BigInteger, nullable=False)
    import_log_id = Column(
        UUID(as_uuid=True), ForeignKey("import_logs.id"), nullable=True
    )
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class ImportedSale(Base):
    """Baris transaksi penjualan dari file Excel laporan penjualan (import berkala admin).

    Disimpan terpisah dari tabel `orders`/`order_items` karena aplikasi ini
    merupakan sistem terpisah dari sistem utama. Sumber file: laporan penjualan
    (rekap detail) yang di-import admin via admin_web.

    Kolom keuangan: `net_per_unit` = N. Jual - Discount (per satuan),
    `total_amount` = total akhir baris; kolom `TOTAL` diprioritaskan (termasuk
    PPN Head), dengan fallback `Total Harga Jual` / `Total Harga Setelah
    Diskon` — bukan dihitung ulang di sisi import.
    """
    __tablename__ = "imported_sales"
    __table_args__ = (
        # Summary filters by (branch, sale_date range). The single-column
        # indexes below are kept for other queries (e.g. trans_no lookups).
        Index(
            "ix_imported_sales_branch_sale_date",
            "branch",
            "sale_date",
        ),
        # Re-import idempotency: one row per deterministic key. Legacy rows
        # keep dedupe_key NULL (PostgreSQL unique indexes allow many NULLs)
        # until the lazy migration or backfill script assigns a key.
        Index(
            "uq_imported_sales_dedupe_key",
            "dedupe_key",
            unique=True,
        ),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    import_log_id = Column(UUID(as_uuid=True), ForeignKey("import_logs.id"), nullable=False, index=True)
    branch = Column(String(20), nullable=True, index=True)
    trans_no = Column(String(50), nullable=True, index=True)
    # ``<md5 base>#<occurrence>``; see app.services.sales_import_keys.
    dedupe_key = Column(String(64), nullable=True)
    # Tanggal penjualan (dari kolom `Penjualan` pada template).
    sale_date = Column(Date, nullable=True, index=True)
    customer_kode = Column(String(50), nullable=True)
    customer_nama = Column(String(200), nullable=True)
    # Channel = tipe langganan (bukan channel sales).
    channel = Column(String(50), nullable=True)
    kategori = Column(String(50), nullable=True)
    # Group = pengelompokan customer (descriptive field).
    customer_group = Column(String(50), nullable=True)
    area = Column(String(50), nullable=True)
    alamat = Column(String(500), nullable=True)
    product_kode = Column(String(50), nullable=True)
    product_nama = Column(String(200), nullable=True)
    qty = Column(Integer, nullable=True)
    satuan_jual = Column(String(50), nullable=True)
    qtyi = Column(Integer, nullable=True)
    satuani = Column(String(50), nullable=True)
    diskon = Column(Integer, nullable=True)
    net_per_unit = Column(Integer, nullable=True)
    total_amount = Column(Integer, nullable=True)
    # Template v2: margin nominal (Rupiah, boleh negatif), mother SKU sebagai
    # kunci produk lintas cabang, dan divisi sebagai dimensi analitik.
    margin = Column(BigInteger, nullable=True)
    mother_sku = Column(String(100), nullable=True)
    divisi = Column(String(100), nullable=True)
    sales_kode = Column(String(50), nullable=True)
    sales_nama = Column(String(200), nullable=True)
    supplier = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    import_log = relationship("ImportLog")


class ImportedReturn(Base):
    """Baris retur penjualan yang diimpor dari laporan Excel."""
    __tablename__ = "imported_returns"
    __table_args__ = (
        Index(
            "ix_imported_returns_branch_sale_date",
            "branch",
            "sale_date",
        ),
        Index(
            "uq_imported_returns_dedupe_key",
            "dedupe_key",
            unique=True,
        ),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    import_log_id = Column(
        UUID(as_uuid=True), ForeignKey("import_logs.id"), nullable=False, index=True
    )
    branch = Column(String(20), nullable=True, index=True)
    sale_date = Column(Date, nullable=False, index=True)
    product_kode = Column(String(50), nullable=True)
    product_nama = Column(String(200), nullable=True)
    mother_sku = Column(String(100), nullable=True)
    divisi = Column(String(100), nullable=True)
    supplier = Column(String(100), nullable=True)
    customer_kode = Column(String(50), nullable=True)
    customer_nama = Column(String(200), nullable=True)
    sales_nama = Column(String(200), nullable=True)
    revenue = Column(BigInteger, nullable=False)
    margin = Column(BigInteger, nullable=True)
    dedupe_key = Column(String(64), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    import_log = relationship("ImportLog")


class SalesImportVersion(Base):
    """Monotonic version counter for imported-sales summaries.

    One row per (scope, month). `scope` is either a branch code or the
    literal ``GLOBAL`` (for global MANAGER). Clients poll the cheap version
    endpoint and only download the heavier summary when the version changes.

    The counter is bumped in the same transaction as a successful import,
    so a failed/rolled-back import never changes it.
    """
    __tablename__ = "sales_import_versions"
    __table_args__ = (
        UniqueConstraint(
            "scope",
            "month",
            name="uq_sales_import_versions_scope_month",
        ),
        Index("ix_sales_import_versions_month", "month"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scope = Column(String(20), nullable=False)
    # YYYY-MM (same format as the summary endpoint).
    month = Column(String(7), nullable=False)
    version = Column(BigInteger, nullable=False, default=0)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class ImportedSalesMonthlySummary(Base):
    """Precomputed top-N aggregation for imported-sales summaries.

    One row per ``(scope, month, dimension, group)``. ``dimension`` is one of
    ``TOTAL``/``PRODUCT``/``SALES``/``CUSTOMER``/``CHANNEL``; ``TOTAL`` stores
    the whole-month totals in a single row (``row_count`` = imported rows),
    while the other dimensions store the top ``SUMMARY_TOP_N`` groups by
    revenue.

    Why precompute: the read endpoint previously ran ``GROUP BY`` over every
    row of the month on each request. With thousands of rows that is both CPU
    and DB→app egress. The table is recomputed in the import transaction (and
    lazily backfilled for legacy data), so reads become a small indexed
    lookup. ``limit`` is capped at ``SUMMARY_TOP_N`` (100) by the API, so the
    stored top-100 always satisfies any request.
    """
    __tablename__ = "imported_sales_monthly_summary"
    __table_args__ = (
        # Read path filters by (scope, month, dimension) then orders by revenue.
        Index(
            "ix_imported_sales_summary_lookup",
            "scope",
            "month",
            "dimension",
            "revenue",
        ),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scope = Column(String(20), nullable=False)
    # YYYY-MM (same format as the summary endpoint).
    month = Column(String(7), nullable=False)
    dimension = Column(String(20), nullable=False)
    # Group key/label are stored as empty strings instead of NULL so ordering
    # and lookups behave deterministically. Empty is mapped back to None by
    # the read helper to preserve the original API response shape.
    dim_key = Column(String(100), nullable=False, default="")
    dim_label = Column(String(200), nullable=False, default="")
    product_kode = Column(String(50), nullable=True)
    mother_sku = Column(String(100), nullable=True)
    qty = Column(BigInteger, nullable=False, default=0)
    revenue = Column(BigInteger, nullable=False, default=0)
    # Margin nominal bulan ini (template v2). 0 untuk data lama.
    margin = Column(BigInteger, nullable=False, default=0)
    retur_revenue = Column(BigInteger, nullable=False, default=0)
    retur_margin = Column(BigInteger, nullable=False, default=0)
    retur_rows = Column(BigInteger, nullable=False, default=0)
    # On RETUR_SUP rows, keeps the corresponding NET supplier omzet for the
    # return-rate denominator.
    supplier_net_revenue = Column(BigInteger, nullable=False, default=0)
    row_count = Column(BigInteger, nullable=False, default=0)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


class ImportedSalesSummaryState(Base):
    """Tracks which source version a precomputed summary was built from.

    ``source_version`` mirrors ``sales_import_versions.version`` for the same
    ``(scope, month)``. The summary endpoint compares both: if the source
    version moved (new import) or the state row is missing (legacy data), it
    recomputes once and updates this row. This is the lazy-backfill mechanism.
    """
    __tablename__ = "imported_sales_summary_state"
    __table_args__ = (
        UniqueConstraint(
            "scope",
            "month",
            name="uq_imported_sales_summary_state_scope_month",
        ),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scope = Column(String(20), nullable=False)
    month = Column(String(7), nullable=False)
    source_version = Column(BigInteger, nullable=False, default=0)
    computed_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class SalesTarget(Base):
    """Target dan incentive per sales per periode (bulanan)."""
    __tablename__ = "sales_targets"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    # periode dalam format YYYY-MM
    period = Column(String(7), nullable=False, index=True)
    # Tipe target: 'ORDER_COUNT' atau 'REVENUE'
    target_type = Column(String(20), nullable=False, default='ORDER_COUNT')
    # Nilai target (jumlah order atau nominal revenue)
    target_value = Column(BigInteger, nullable=False, default=0)
    # Bonus/incentive kalau target tercapai
    incentive_amount = Column(BigInteger, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_sales_targets_user_period", "user_id", "period", unique=True),
    )

    user = relationship("User")


class SupplierTarget(Base):
    """Target penjualan per supplier per periode (bulanan).

    Supplier di sini adalah free-text `Product.nama_supplier` (VARCHAR, bukan FK).
    Carry-over dari bulan sebelumnya di-handle di read-time di endpoint, bukan
    via trigger — supaya satu source of truth (row eksplisit saja di tabel).
    """
    __tablename__ = "supplier_targets"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    branch = Column(String(20), nullable=False, index=True)
    supplier_name = Column(String, nullable=False)
    period = Column(String(7), nullable=False, index=True)
    target_value = Column(BigInteger, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    __table_args__ = (
        UniqueConstraint(
            "branch",
            "supplier_name",
            "period",
            name="uq_supplier_targets_branch_supplier_period",
        ),
        Index("ix_supplier_targets_branch_period", "branch", "period"),
    )


class Supplier(Base):
    __tablename__ = "suppliers"

    name = Column(String, primary_key=True)  # matches Product.nama_supplier
    is_active = Column(Boolean, nullable=False, default=True)
    order_type = Column(String(10), nullable=False, default="REGULER")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class Bulletin(Base):
    __tablename__ = "bulletins"
    __table_args__ = (
        Index("ix_bulletins_expire_at", "expire_at"),
        Index("ix_bulletins_created_at", "created_at"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Branch scoping: NULL = global bulletin (visible to all branches).
    branch = Column(String(20), nullable=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)  # teks promo/deskripsi
    pdf_url = Column(String(500), nullable=True)  # URL ke file PDF
    expire_at = Column(DateTime(timezone=True), nullable=True)  # nullable = tidak expire
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class BulletinDismiss(Base):
    """Tracking apakah sales sudah dismiss popup bulletin."""
    __tablename__ = "bulletin_dismisses"
    __table_args__ = (
        Index("ix_bd_bulletin_user", "bulletin_id", "sales_id", unique=True),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    bulletin_id = Column(UUID(as_uuid=True), ForeignKey("bulletins.id"), nullable=False)
    sales_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    dismissed_at = Column(DateTime(timezone=True), server_default=func.now())

    bulletin = relationship("Bulletin")
    user = relationship("User")

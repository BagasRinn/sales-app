import uuid
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Index, Boolean, Text, BigInteger, JSON
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
    is_active = Column(Boolean, default=True, nullable=False)
    token_version = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    orders = relationship("Order", back_populates="sales")


class Product(Base):
    __tablename__ = "products"

    id = Column(String, primary_key=True, index=True)
    nama_barang = Column(String, index=True)
    harga = Column(Integer)
    stok_sistem = Column(Integer, default=0)
    stok_booking = Column(Integer, default=0)
    kategori = Column(String, nullable=True)
    satuan = Column(String, nullable=True)
    nama_supplier = Column(String, nullable=True)
    # Tipe order: 'REGULER' atau '4P'. Default REGULER — supervisor yg
    # nanti set 4P per produk via admin web. Dipakai buat filter order flow
    # mobile + validasi item harus cocok dgn order.order_type.
    order_type = Column(String(10), nullable=False, default='REGULER')


class Customer(Base):
    __tablename__ = "customers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kode = Column(String(50), nullable=True, index=True)
    nama_toko = Column(String(200), nullable=False, index=True)
    alamat = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    orders = relationship("Order", back_populates="customer")


class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
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

    __table_args__ = (
        Index("ix_orders_status", "status"),
        Index("ix_orders_created_at", "created_at"),
        Index("ix_orders_status_created_at", "status", "created_at"),
        Index("ix_orders_sales_id", "sales_id"),
        Index("ix_orders_customer_id", "customer_id"),
    )

    sales = relationship("User", back_populates="orders")
    customer = relationship("Customer", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", lazy="select")


class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id = Column(UUID(as_uuid=True), ForeignKey("orders.id"))
    product_id = Column(String, ForeignKey("products.id"))
    qty = Column(Integer)

    # --- Discount Layer 1 (existing single discount, retained as layer 1) ---
    discount_percent = Column(Integer, default=0)  # dipakai kalau discount_type == 'PERCENT'
    discount_type = Column(String(10), default='PERCENT')  # 'PERCENT' atau 'NOMINAL'
    discount_nominal = Column(Integer, default=0)  # dipakai kalau discount_type == 'NOMINAL', dalam IDR

    # --- Discount Layer 2 (stacked setelah Layer 1, sequential) ---
    discount2_type = Column(String(10), default='PERCENT', nullable=False)
    discount2_percent = Column(Integer, default=0, nullable=False)
    discount2_nominal = Column(Integer, default=0, nullable=False)

    # --- Discount Layer 3 (stacked setelah Layer 2, sequential) ---
    discount3_type = Column(String(10), default='PERCENT', nullable=False)
    discount3_percent = Column(Integer, default=0, nullable=False)
    discount3_nominal = Column(Integer, default=0, nullable=False)

    order = relationship("Order", back_populates="items")
    product = relationship("Product")


class StokLog(Base):
    __tablename__ = "stok_log"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id = Column(String, ForeignKey("products.id"), index=True)
    sumber = Column(String(20))
    field_terdampak = Column(String(20))
    delta = Column(Integer)
    nilai_sebelum = Column(Integer)
    nilai_sesudah = Column(Integer)
    actor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    order_id = Column(UUID(as_uuid=True), ForeignKey("orders.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class CustomerRegistrationSubmission(Base):
    """Pengajuan customer baru dari sales. Approve → bikin Customer baru dengan kode yg diinput admin."""
    __tablename__ = "customer_registration_submissions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
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
    created_at = Column(DateTime(timezone=True), server_default=func.now())


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


class Bulletin(Base):
    __tablename__ = "bulletins"
    __table_args__ = (
        Index("ix_bulletins_expire_at", "expire_at"),
        Index("ix_bulletins_created_at", "created_at"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
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

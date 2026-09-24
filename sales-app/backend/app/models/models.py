import uuid
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Index, Boolean
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
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    orders = relationship("Order", back_populates="sales")
    customer_assignments = relationship("CustomerSales", back_populates="sales")


class Product(Base):
    __tablename__ = "products"

    id = Column(String, primary_key=True, index=True)
    nama_barang = Column(String, index=True)
    harga = Column(Integer)
    stok_sistem = Column(Integer, default=0)
    stok_booking = Column(Integer, default=0)
    kategori = Column(String, nullable=True)
    satuan = Column(String, nullable=True)


class Customer(Base):
    __tablename__ = "customers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kode = Column(String(50), nullable=True, index=True)
    nama_toko = Column(String(200), nullable=False, index=True)
    alamat = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    assignments = relationship("CustomerSales", back_populates="customer", cascade="all, delete-orphan")
    orders = relationship("Order", back_populates="customer")


class CustomerSales(Base):
    __tablename__ = "customer_sales"

    customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id", ondelete="CASCADE"), primary_key=True)
    sales_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    assigned_at = Column(DateTime(timezone=True), server_default=func.now())

    customer = relationship("Customer", back_populates="assignments")
    sales = relationship("User", back_populates="customer_assignments")


class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sales_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=True)
    status = Column(String(20), default="DRAFT")
    notes = Column(String(1000), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expired_at = Column(DateTime(timezone=True))
    store_name = Column(String(200), nullable=True)
    store_contact = Column(String(50), nullable=True)
    store_address = Column(String(500), nullable=True)

    __table_args__ = (
        Index("ix_orders_status", "status"),
        Index("ix_orders_created_at", "created_at"),
        Index("ix_orders_expired_at", "expired_at"),
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
    discount_percent = Column(Integer, default=0)

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


class SyncValidationError(Base):
    """Persisted validation errors from a sync run — used by GET /products/sync/errors."""
    __tablename__ = "sync_validation_errors"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    row_number = Column(Integer)
    sku = Column(String, nullable=True)
    reason = Column(String(255))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ImportLog(Base):
    """Tracks every Excel import run."""
    __tablename__ = "import_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, nullable=True)
    username = Column(String, nullable=True)
    total_rows = Column(Integer, default=0)
    inserted = Column(Integer, default=0)
    updated = Column(Integer, default=0)
    skipped = Column(Integer, default=0)
    file_name = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

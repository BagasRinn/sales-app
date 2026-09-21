import uuid
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Index
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

    orders = relationship("Order", back_populates="sales")


class Product(Base):
    __tablename__ = "products"

    id = Column(String, primary_key=True, index=True)
    nama_barang = Column(String, index=True)
    harga = Column(Integer)
    stok_sistem = Column(Integer, default=0)
    stok_booking = Column(Integer, default=0)


class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sales_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    status = Column(String(20), default="PENDING")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expired_at = Column(DateTime(timezone=True))
    store_name = Column(String(200), nullable=True)
    store_contact = Column(String(50), nullable=True)
    store_address = Column(String(500), nullable=True)

    sales = relationship("User", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", lazy="joined")


class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id = Column(UUID(as_uuid=True), ForeignKey("orders.id"))
    product_id = Column(String, ForeignKey("products.id"))
    qty = Column(Integer)

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

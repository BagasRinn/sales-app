from sqlalchemy.orm import Session
from app.models.models import Product
from app.schemas.schemas import ProductCreate

def process_bulk_products(db: Session, products_data: list[ProductCreate]):
    try:
        # Menyimpan data dalam jumlah banyak
        db_products = [
            Product(
                id=item.id,
                nama_barang=item.nama_barang,
                harga=item.harga,
                stok_sistem=item.stok_sistem,
                stok_booking=item.stok_booking
            ) for item in products_data
        ]
        
        db.add_all(db_products)
        db.commit()
        print(f"Berhasil menyimpan {len(db_products)} data produk ke database.")
    except Exception as e:
        db.rollback()
        print(f"Terjadi kesalahan saat menyimpan data: {e}")
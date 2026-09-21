import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Memuat variabel dari file .env
load_dotenv()

# Mengambil URL database
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")

# Membuat Engine (Mesin Koneksi)
# pool_size dan max_overflow diatur untuk menangani koneksi konkuren dari sales
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_size=20,
    max_overflow=10
)

# Membuat SessionLocal yang akan digunakan setiap kali ada request datang
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Dependency untuk FastAPI: memastikan koneksi database ditutup setelah request selesai
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
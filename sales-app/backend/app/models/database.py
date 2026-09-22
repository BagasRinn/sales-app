import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Memuat variabel dari file .env
load_dotenv()

# Mengambil URL database
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "")

# psycopg v3 requires postgresql+psycopg:// prefix; add it if missing
if SQLALCHEMY_DATABASE_URL and "+psycopg" not in SQLALCHEMY_DATABASE_URL:
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace(
        "postgresql://", "postgresql+psycopg://", 1
    )

# Membuat Engine (Mesin Koneksi)
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=1800,
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

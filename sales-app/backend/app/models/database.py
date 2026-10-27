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

# QueuePool: reuse koneksi supaya tidak bayar TCP+TLS handshake ke Supabase
# tiap request (NullPool sebelumnya). Sizing sengaja kecil (5+5=10) karena
# Supavisor SESSION mode (port 5432) punya limit ~15 koneksi per client —
# overflow ke atas itu bikin "max clients reached". Naikkan pool_size kalau
# DATABASE_URL pindah ke transaction mode pooler (port 6543) dan traffic naik.
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_size=5,
    max_overflow=5,
    pool_timeout=30,
    pool_pre_ping=True,   # buang koneksi stale sebelum dipakai
    pool_recycle=1800,    # recycle tiap 30 menit
    # psycopg3 auto-prepare setelah 5 eksekusi query yang sama. Di balik
    # Supavisor, server connection dipakai ulang lintas client → nama
    # prepared statement bentrok ("prepared statement _pg3_N already exists").
    # Matikan auto-prepare; biar tiap statement di-parse ulang (tetap cached
    # di server lewat generic plan Postgres).
    connect_args={"prepare_threshold": None},
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

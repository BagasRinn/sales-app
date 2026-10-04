import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool
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

# NullPool: setiap request buka koneksi baru lalu close — kompatibel dengan
# Supabase Supavisor session mode yang limit ~15 koneksi per client.
# Default pool (QueuePool) overflow di atas limit itu → "max clients reached".
# Trade-off: extra latency untuk TCP+TLS handshake per request. Untuk traffic
# tinggi nanti, switch DATABASE_URL ke transaction mode pooler (port 6543)
# dan kembali ke QueuePool dengan pool_size yang lebih besar.
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    poolclass=NullPool,
    pool_pre_ping=True,
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

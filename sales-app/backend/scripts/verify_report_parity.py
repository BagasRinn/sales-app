"""Read-only: card dashboard MTD == popup detail == total bulanan per cabang.

Jalankan (pakai DB di .env, tidak menulis apa pun):
    python scripts/verify_report_parity.py

Yang dicek per cabang × status (APPROVED/PENDING/REJECTED) dan untuk total
perusahaan (semua cabang):
- jumlah order & rupiah dari /reports/sales-performance/dashboard (hitung
  Python) == GET /orders dengan filter tanggal bulan berjalan (hitung SQL);
- rounding diskon/up price SQL harus identik dengan rumus Python.
"""
import os
import sys
from datetime import datetime, timedelta, timezone

from dotenv import load_dotenv

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
load_dotenv(os.path.join(ROOT, ".env"))

from fastapi import Response  # noqa: E402

from app.api.endpoints.orders import list_all_orders  # noqa: E402
from app.api.endpoints.reports import (  # noqa: E402
    cross_branch_sales_summary,
    sales_performance_dashboard,
)
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from app.models.database import SQLALCHEMY_DATABASE_URL  # noqa: E402

WITA = timezone(timedelta(hours=8))
today = datetime.now(WITA).date()
DATE_FROM = today.replace(day=1).isoformat()
DATE_TO = today.isoformat()
adm = {"role": "MANAGER", "branch": None}

db = sessionmaker(
    bind=create_engine(
        SQLALCHEMY_DATABASE_URL,
        # Supavisor reuse koneksi server yang masih punya prepared statement
        # dari client sebelumnya → psycopg3 "prepared statement _pg3_0 exists".
        connect_args={"prepare_threshold": None},
    )
)()
ok = True
try:
    res = sales_performance_dashboard(db=db, current_user=adm)
    branches = sorted({s.branch for s in res.sales if s.branch}) + [None]
    for branch in branches:
        label = f"{branch or 'SEMUA CABANG':13s}"
        rows = [s for s in res.sales if branch is None or s.branch == branch]
        for status in ("APPROVED", "PENDING", "REJECTED"):
            key = status.lower()
            exp_cnt = sum(getattr(s, f"{key}_mtd_count") for s in rows)
            exp_amt = sum(getattr(s, f"{key}_mtd_revenue") for s in rows)
            got = list_all_orders(
                Response(),
                status_filter=status,
                date_from=DATE_FROM,
                date_to=DATE_TO,
                search=None,
                sales_id=None,
                branch=branch,
                skip=0,
                limit=1,
                db=db,
                current_user=adm,
            )
            match = (got["total"], got["total_amount"]) == (exp_cnt, exp_amt)
            ok &= match
            print(
                f"{label} {status:9s} card={exp_cnt:5d}/Rp {exp_amt:<13,d}"
                f" popup={got['total']:5d}/Rp {got['total_amount']:<13,d}"
                f" {'OK' if match else 'MISMATCH'}"
            )

    # Laporan lintas cabang (halaman "Laporan") harus pakai periode yang sama.
    cb = cross_branch_sales_summary(db=db, current_user=adm)
    for row in cb["branches"]:
        items = [s for s in res.sales if s.branch == row["branch"]]
        exp_cnt = sum(s.approved_mtd_count for s in items)
        exp_amt = sum(s.approved_mtd_revenue for s in items)
        match = (row["approved_count"], row["approved_revenue"]) == (exp_cnt, exp_amt)
        ok &= match
        print(
            f"{'LINTAS CABANG':13s} {row['branch']:13s} dashboard={exp_cnt:5d}/Rp {exp_amt:<13,d}"
            f" laporan={row['approved_count']:5d}/Rp {row['approved_revenue']:<13,d}"
            f" {'OK' if match else 'MISMATCH'}"
        )
finally:
    db.close()

print("\nSEMUA MATCH" if ok else "\nADA MISMATCH")
sys.exit(0 if ok else 1)

#!/usr/bin/env python3
"""
Script untuk approve semua order dengan tanggal <= 20 (hari ke-20) 
untuk semua sales di semua cabang.

Usage:
    cd sales-app/backend
    python approve_orders_before_20.py [--dry-run]
"""

import sys
import os
from datetime import datetime
from sqlalchemy import extract

# Add parent directory to path to import app modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.models.database import SessionLocal
from app.models.models import Order

def approve_orders_before_20(dry_run: bool = False):
    db = SessionLocal()
    try:
        # Query orders where day of created_at <= 20
        # We need to extract the day from created_at (which is timezone-aware)
        orders = db.query(Order).filter(
            extract('day', Order.created_at) <= 20
        ).all()
        
        print(f"Ditemukan {len(orders)} order dengan tanggal <= 20")
        
        # Group by current status for reporting
        status_counts = {}
        for order in orders:
            status_counts[order.status] = status_counts.get(order.status, 0) + 1
        
        print("Distribusi status sebelum update:")
        for status, count in sorted(status_counts.items()):
            print(f"  {status}: {count}")
        
        if dry_run:
            print("\n[DRY RUN] Tidak ada perubahan yang disimpan.")
            return
        
        # Update status to APPROVED
        updated = 0
        for order in orders:
            if order.status != 'APPROVED':
                order.status = 'APPROVED'
                updated += 1
        
        db.commit()
        print(f"\nBerhasil update {updated} order ke status APPROVED")
        
        # Verify
        remaining = db.query(Order).filter(
            extract('day', Order.created_at) <= 20,
            Order.status != 'APPROVED'
        ).count()
        print(f"Order dengan tanggal <= 20 yang belum APPROVED: {remaining}")
        
    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    if dry_run:
        print("=== DRY RUN MODE ===\n")
    approve_orders_before_20(dry_run=dry_run)
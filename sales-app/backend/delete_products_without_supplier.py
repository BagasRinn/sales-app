"""Hapus produk yang tidak punya supplier (nama_supplier NULL atau kosong).

    cd backend
    python delete_products_without_supplier.py --dry-run   # lihat dulu
    python delete_products_without_supplier.py             # hapus (skip yg ada order)
    python delete_products_without_supplier.py --force     # ikut hapus order_items

Default: produk yang sudah dipakai di order_items TIDAK dihapus (dilaporkan),
supaya riwayat order tidak hilang. --force menghapus order_items-nya juga.
stok_log selalu ikut dihapus — audit stok tidak berguna tanpa produknya.
"""
import argparse

from sqlalchemy import text

from app.models.database import engine

NO_SUPPLIER = "p.nama_supplier IS NULL OR btrim(p.nama_supplier) = ''"

QUERY = f"""
    SELECT p.id, p.branch, p.nama_barang,
           (SELECT count(*) FROM order_items oi
             WHERE oi.product_id = p.id AND oi.branch = p.branch) AS order_items,
           (SELECT count(*) FROM stok_log s
             WHERE s.product_id = p.id AND s.branch = p.branch) AS stok_log
    FROM products p
    WHERE {NO_SUPPLIER}
    ORDER BY p.branch, p.id
"""


def main() -> None:
    ap = argparse.ArgumentParser(description="Hapus produk tanpa supplier")
    ap.add_argument("--dry-run", action="store_true", help="cuma tampilkan, tidak hapus")
    ap.add_argument("--force", action="store_true", help="hapus juga order_items")
    args = ap.parse_args()

    with engine.begin() as conn:
        rows = conn.execute(text(QUERY)).all()

        print(f"[INFO] {len(rows)} produk tanpa supplier")
        if not rows:
            return

        blocked = [r for r in rows if r.order_items and not args.force]
        targets = [r for r in rows if not (r.order_items and not args.force)]

        for r in rows:
            mark = "SKIP (punya order)" if r in blocked else "HAPUS"
            print(f"       [{mark}] {r.branch}/{r.id} | {r.nama_barang} | order_items={r.order_items} stok_log={r.stok_log}")

        if args.dry_run:
            print(f"[DRY-RUN] akan hapus {len(targets)} produk, skip {len(blocked)}")
            return

        # Hapus child row dulu — FK (product_id, branch) ke products tidak ON DELETE CASCADE.
        for r in targets:
            pair = {"pid": r.id, "pbranch": r.branch}
            conn.execute(
                text("DELETE FROM stok_log WHERE product_id = :pid AND branch = :pbranch"),
                pair,
            )
            if args.force:
                conn.execute(
                    text("DELETE FROM order_items WHERE product_id = :pid AND branch = :pbranch"),
                    pair,
                )
            conn.execute(
                text("DELETE FROM products WHERE id = :pid AND branch = :pbranch"),
                pair,
            )

        print(f"[OK] {len(targets)} produk dihapus | {len(blocked)} di-skip")
        if blocked:
            print("[WARN] Produk di-skip karena sudah dipakai di order. Jalankan dengan --force kalau memang mau dihapus.")


if __name__ == "__main__":
    main()

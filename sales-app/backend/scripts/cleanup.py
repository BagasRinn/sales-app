"""
Bersihkan file-file hasil migrasi sebelum push ke git.
Hapus: exports (data sensitif) + script migrasi Railway lama.
"""

import os
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.dirname(SCRIPT_DIR)
EXPORTS_DIR = os.path.join(BACKEND_DIR, "exports")

# File script yang dihapus
SCRIPTS_TO_DELETE = [
    "migrate_to_railway.py",
    "create_tables_railway.py",
    "migrate_storage_to_s3.py",
]

def cleanup():
    deleted = []
    errors = []

    # Hapus folder exports
    if os.path.exists(EXPORTS_DIR):
        try:
            shutil.rmtree(EXPORTS_DIR)
            deleted.append("exports/")
        except Exception as e:
            errors.append(f"exports/: {e}")

    # Hapus script yang tidak terpakai
    for script in SCRIPTS_TO_DELETE:
        path = os.path.join(SCRIPT_DIR, script)
        if os.path.exists(path):
            try:
                os.remove(path)
                deleted.append(f"scripts/{script}")
            except Exception as e:
                errors.append(f"scripts/{script}: {e}")

    print("Cleanup selesai.\n")
    if deleted:
        print("Dihapus:")
        for f in deleted:
            print(f"  - {f}")
    if errors:
        print("\nError:")
        for f in errors:
            print(f"  - {f}")
    if not deleted and not errors:
        print("Tidak ada yang dihapus (sudah bersih)")


if __name__ == "__main__":
    cleanup()

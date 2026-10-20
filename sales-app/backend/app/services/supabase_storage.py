"""
DEPRECATED — gunakan app.services.storage sebagai gantinya.

File ini dipertahankan untuk backward compatibility.
Semua kode baru harus import dari:
    from app.services.storage import upload_pdf, delete_file
"""
from app.services.storage import upload_pdf, delete_file

__all__ = ["upload_pdf", "delete_file"]

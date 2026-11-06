**1. Tabel Branches**

Tabel branches berfungsi untuk menyimpan data master cabang yang menjadi acuan pembatasan data pada sistem. Setiap cabang memiliki kode unik, nama, dan status aktif. Tabel ini digunakan untuk memisahkan data pengguna, produk, customer, order, dan data operasional lain berdasarkan cabang, sehingga setiap cabang hanya mengakses data miliknya, sedangkan MANAGER global dapat melihat seluruh cabang.

**2. Tabel Users**

Tabel users berfungsi untuk menyimpan data akun pengguna yang terdaftar pada sistem. Tabel ini memuat username, password yang sudah di-hash, nama, role, cabang, serta status aktif akun. Data pada tabel ini digunakan untuk proses autentikasi dan otorisasi, termasuk menentukan hak akses pengguna sebagai ADMIN, SUPERVISOR, MANAGER, atau SALES.

**3. Tabel Products**

Tabel products berfungsi untuk menyimpan data master produk pada setiap cabang. Tabel ini memuat nama barang, harga, kategori, satuan, supplier, tipe order, serta informasi stok yang terdiri atas stok sistem, stok booking, dan stok diterima. Data produk digunakan sebagai acuan katalog, pengecekan ketersediaan stok, dan penyusunan item order.

**4. Tabel Customers**

Tabel customers berfungsi untuk menyimpan data master customer atau toko yang menjadi tujuan order sales. Tabel ini memuat kode customer, nama toko, alamat, dan kode area. Data customer digunakan sebagai acuan pembuatan order, penugasan sales, serta penentuan customer yang dapat diakses oleh masing-masing sales.

**5. Tabel Suppliers**

Tabel suppliers berfungsi untuk menyimpan data master supplier yang bekerja sama dengan perusahaan. Tabel ini memuat nama supplier, status aktif, dan tipe order yang digunakan. Data supplier menjadi acuan pengelompokan produk serta penyusunan target penjualan per supplier.

**6. Tabel Orders**

Tabel orders berfungsi untuk menyimpan data utama atau header dari setiap order yang dibuat oleh sales. Tabel ini memuat informasi sales, customer, cabang, status order, tipe order, data toko, diskon, up price, serta nomor invoice. Tabel ini menjadi inti transaksi karena digunakan untuk memantau proses pengajuan, persetujuan, penolakan, dan pembatalan order.

**7. Tabel Order Items**

Tabel order_items berfungsi untuk menyimpan rincian produk yang terdapat pada setiap order. Tabel ini memuat produk, jumlah yang dipesan, diskon bertingkat, dan up price per item. Data pada tabel ini digunakan untuk menghitung nilai order, menampilkan detail pesanan, dan menentukan jumlah stok yang harus dibooking atau dikurangi.

**8. Tabel Stok Log**

Tabel stok_log berfungsi untuk mencatat seluruh riwayat perubahan stok produk. Tabel ini menyimpan sumber perubahan, kolom stok yang terdampak, nilai perubahan, nilai sebelum dan sesudah, pengguna yang melakukan perubahan, serta order yang terkait. Data ini digunakan sebagai audit trail untuk menelusuri penyebab perbedaan stok.

**9. Tabel Customer Assignments**

Tabel customer_assignments berfungsi untuk menyimpan penugasan customer tertentu kepada sales. Tabel ini menghubungkan customer dengan sales serta mencatat pengguna yang melakukan penugasan. Data pada tabel ini digunakan untuk menentukan customer mana yang dapat diakses dan dilayani oleh setiap sales.

**10. Tabel Area Assignments**

Tabel area_assignments berfungsi untuk menyimpan penugasan area atau rayon kepada sales. Tabel ini memuat kode area, sales, cabang, dan pengguna yang melakukan penugasan. Customer dengan kode area yang sama akan otomatis masuk ke cakupan sales tersebut, sehingga tabel ini membantu pengaturan wilayah kerja sales.

**11. Tabel Customer Registration Submissions**

Tabel customer_registration_submissions berfungsi untuk menyimpan pengajuan customer baru yang diajukan oleh sales. Tabel ini memuat data calon customer, status pengajuan, alasan penolakan, serta referensi customer yang dihasilkan setelah pengajuan disetujui. Data ini digunakan untuk mendukung proses pengajuan dan persetujuan customer baru oleh admin atau supervisor.

**12. Tabel Sales Targets**

Tabel sales_targets berfungsi untuk menyimpan target penjualan dan insentif setiap sales pada periode tertentu. Tabel ini memuat periode, jenis target, nilai target, dan nominal insentif. Data pada tabel ini digunakan untuk memantau pencapaian target dan menghitung insentif sales.

**13. Tabel Supplier Targets**

Tabel supplier_targets berfungsi untuk menyimpan target penjualan per supplier pada setiap cabang dan periode. Tabel ini memuat nama supplier, periode, dan nilai target. Data tersebut digunakan untuk mengevaluasi kinerja supplier serta membandingkan realisasi penjualan dengan target yang telah ditetapkan.

**14. Tabel Bulletins**

Tabel bulletins berfungsi untuk menyimpan pengumuman atau informasi yang ditampilkan kepada sales. Tabel ini memuat judul, deskripsi, tautan file PDF, masa berlaku, dan cabang tujuan. Bulletin dapat bersifat global untuk seluruh cabang atau khusus untuk cabang tertentu, sehingga tabel ini menjadi media komunikasi antara admin dan sales.

**15. Tabel Bulletin Dismisses**

Tabel bulletin_dismisses berfungsi untuk mencatat bulletin yang telah ditutup atau di-dismiss oleh sales. Tabel ini menyimpan referensi bulletin, sales yang menutupnya, dan waktu penutupan. Data ini digunakan agar bulletin yang sudah dibaca tidak terus muncul pada aplikasi sales.

**16. Tabel Import Logs**

Tabel import_logs berfungsi untuk mencatat riwayat proses impor data dari file Excel. Tabel ini memuat jenis impor, nama file, jumlah baris yang diproses, jumlah data yang berhasil ditambahkan atau diperbarui, serta jumlah data yang dilewati. Data ini digunakan untuk memantau dan menelusuri aktivitas impor yang dilakukan admin.

**17. Tabel Sync Validation Errors**

Tabel sync_validation_errors berfungsi untuk menyimpan detail baris data yang gagal divalidasi pada saat proses impor. Tabel ini memuat nomor baris, kode produk, dan alasan kegagalan validasi. Data ini digunakan oleh admin untuk memperbaiki file impor dan mengetahui penyebab data tertentu tidak berhasil diproses.

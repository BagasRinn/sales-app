# Perancangan Antarmuka Sistem

## 3.4 Perancangan Antarmuka Sistem

Perancangan antarmuka merupakan tahap yang menghubungkan pengguna dengan sistem. Antarmuka yang baik tidak hanya menampilkan data, tetapi juga mengarahkan pengguna menyelesaikan pekerjaannya dengan jelas, yaitu mulai dari memasukkan data, memeriksa status, hingga memperoleh informasi hasil pengolahan. Pada sistem manajemen order sales ini, perancangan antarmuka disesuaikan dengan tugas dan wewenang masing-masing pengguna, sehingga sales dapat bekerja dengan cepat di lapangan, sedangkan admin, supervisor, dan manager dapat mengelola data serta memantau kinerja secara terpusat.

Sistem dibangun menggunakan Flutter dengan satu basis kode yang dapat dijalankan pada beberapa platform. Implementasinya terdiri atas tiga klien, yaitu aplikasi mobile sales, aplikasi sales web, dan aplikasi admin web. Aplikasi mobile sales dan sales web memiliki fungsi yang sama, yakni pembuatan order, pemantauan pesanan, pencarian katalog produk, pengajuan customer baru, dan pembacaan bulletin. Perbedaannya terletak pada media akses; aplikasi mobile digunakan sales di lapangan melalui ponsel, sedangkan sales web digunakan melalui peramban pada layar yang lebih lebar. Aplikasi admin web digunakan oleh ADMIN, SUPERVISOR, dan MANAGER untuk mengelola data master, memproses pesanan, mengatur penugasan sales, menetapkan target, serta mengunduh laporan.

Agar tampilan tetap konsisten, ketiga klien menggunakan satu *design system* yang sama. Elemen visual seperti warna, tipografi, jarak, kartu, tombol, kolom masukan, dan label status disusun dalam komponen yang dapat dipakai berulang. Warna utama yang digunakan adalah biru tua, dengan latar terang dan tipografi *Plus Jakarta Sans*. Warna status dibuat seragam, yaitu hijau untuk kondisi berhasil atau disetujui, kuning untuk kondisi menunggu atau stok rendah, merah untuk penolakan atau stok habis, biru untuk informasi, dan abu-abu untuk data draft. Konsistensi ini bertujuan agar pengguna tidak perlu mempelajari ulang arti warna dan bentuk komponen pada setiap halaman.

Antarmuka dirancang responsif terhadap ukuran layar. Pada aplikasi sales, navigasi berupa bilah bawah (*bottom navigation bar*) ketika layar berukuran kecil, berubah menjadi *navigation rail* pada layar sedang, dan menjadi panel navigasi di sisi kiri pada layar lebar. Pada aplikasi admin web, lebar layar dibagi menjadi tiga kategori, yaitu layar kecil di bawah 600 piksel, tablet antara 600 sampai 1024 piksel, dan desktop di atas 1024 piksel. Layar desktop menampilkan *sidebar* tetap selebar 256 piksel, sedangkan layar kecil dan tablet memindahkan menu ke dalam *drawer*. Tabel yang panjang pada layar kecil diubah menjadi susunan kartu agar informasi tetap terbaca tanpa harus menggeser layar ke samping. Jarak tepi, ukuran kartu, dan tinggi bilah atas juga menyesuaikan kategori layar tersebut.

Navigasi disusun berdasarkan peran pengguna. Pada aplikasi sales terdapat empat menu utama, yaitu Beranda, Pesanan, Katalog, dan Lainnya, ditambah tombol Order Baru yang selalu tersedia. Pada aplikasi admin web, menu dikelompokkan menjadi kelompok Utama, Data, Operasional, dan Manajemen. Menu User, Performa Sales, Penugasan Sales, dan Bulletin hanya ditampilkan untuk SUPERVISOR dan MANAGER, sedangkan menu Laporan Lintas Cabang hanya ditampilkan untuk MANAGER global. ADMIN tidak melihat menu manajemen tersebut karena tugasnya berfokus pada pengelolaan data operasional cabang. Selain penyaringan menu, data yang ditampilkan juga dibatasi oleh cabang pengguna, kecuali MANAGER yang dapat memilih seluruh cabang atau cabang tertentu.

Penyajian struktur navigasi secara ringkas ditunjukkan pada Tabel 3.18.

**Tabel 3.18 Struktur Navigasi Antarmuka Sistem**

| No | Aplikasi | Pengguna | Menu Utama | Keterangan |
|---:|---|---|---|---|
| 1 | Mobile sales | SALES | Beranda, Pesanan, Katalog, Lainnya | Tombol Order Baru tersedia di seluruh halaman utama. |
| 2 | Sales web | SALES | Beranda, Pesanan, Katalog, Lainnya | Fungsi sama dengan mobile, tata letak menyesuaikan layar lebar. |
| 3 | Admin web | ADMIN, SUPERVISOR, MANAGER | Dashboard, Pesanan, Toko, Pengajuan Customer, Produk & Stok, Supplier, Sinkronisasi | Menu operasional dan data master. |
| 4 | Admin web | SUPERVISOR, MANAGER | User, Performa Sales, Penugasan Sales, Bulletin | Menu manajemen; ADMIN tidak memiliki akses. |
| 5 | Admin web | MANAGER | Laporan Lintas Cabang | Hanya untuk MANAGER global yang dapat melihat seluruh cabang. |

Antarmuka juga memberikan umpan balik atas setiap proses yang dilakukan pengguna. Saat data sedang dimuat, sistem menampilkan indikator pemuatan atau kerangka konten. Apabila data kosong, sistem menampilkan pesan dan saran tindakan, misalnya mengubah kata kunci pencarian atau menambahkan data baru. Apabila terjadi kesalahan, pengguna memperoleh pesan yang menjelaskan penyebabnya beserta tombol untuk mencoba lagi. Setelah proses berhasil, sistem menampilkan notifikasi singkat, sedangkan untuk tindakan yang tidak dapat dibatalkan, seperti menghapus data, menolak pesanan, atau membatalkan item, sistem meminta konfirmasi terlebih dahulu.

Dari sisi keamanan, antarmuka hanya menampilkan menu dan data yang sesuai dengan hak akses pengguna. Setelah login, sistem menyimpan token akses yang digunakan untuk setiap permintaan data. Apabila token tidak lagi berlaku atau pengguna tidak melakukan aktivitas, sistem mengarahkan pengguna kembali ke halaman login. Pada aplikasi admin web, batas waktu tidak aktif ditetapkan 15 menit. Penyaringan menu pada antarmuka bukan satu-satunya pengaman, karena server tetap memeriksa peran dan cabang pengguna pada setiap permintaan.

## 3.4.1 Perancangan Antarmuka Masukan Sistem

Antarmuka masukan adalah bagian sistem yang digunakan pengguna untuk memasukkan data ke dalam basis data. Pada sistem ini, antarmuka masukan mencakup proses autentikasi, pembuatan order, pengajuan customer baru, pengelolaan data master oleh admin, penetapan target, serta impor data dari file Excel. Setiap kolom masukan dilengkapi label, petunjuk pengisian, dan aturan validasi agar data yang tersimpan sesuai dengan kebutuhan sistem.

### a. Antarmuka Login dan Perubahan Password

Halaman login merupakan pintu masuk seluruh pengguna. Antarmuka ini memuat kolom username, kolom password yang dapat ditampilkan atau disembunyikan, tombol Masuk, serta pesan kesalahan apabila autentikasi gagal. Setelah login berhasil, pengguna diarahkan ke halaman utama sesuai perannya, yaitu aplikasi sales untuk pengguna SALES dan dashboard admin untuk pengguna ADMIN, SUPERVISOR, atau MANAGER. Apabila akun tidak aktif atau kombinasi username dan password salah, sistem menampilkan pesan yang tidak mengungkap data sensitif.

Perubahan password dilakukan melalui dialog Ganti Password yang memuat password lama, password baru, dan konfirmasi password baru. Sistem memeriksa kecocokan konfirmasi serta panjang password minimal enam karakter sebelum menyimpan perubahan. Setelah password diubah, pengguna diminta login ulang dan token sesi sebelumnya tidak lagi berlaku sehingga keamanan akun tetap terjaga. Tampilan halaman login ditunjukkan pada Gambar 3.6.

### b. Antarmuka Pembuatan Order pada Aplikasi Sales

Pembuatan order dilakukan melalui alur empat langkah yang ditampilkan dengan indikator kemajuan, yaitu Toko, Tipe, Produk, dan Review. Indikator ini membantu sales mengetahui posisi pekerjaannya dan memungkinkan kembali ke langkah sebelumnya. Apabila sales keluar di tengah proses, sistem menampilkan konfirmasi agar draft tidak hilang tanpa sengaja.

Langkah pertama adalah pemilihan toko. Antarmuka menampilkan kolom pencarian toko, daftar customer yang menjadi cakupan sales, serta tombol untuk mengajukan customer baru. Setiap kartu customer memuat kode customer, nama toko, dan alamat. Sales hanya dapat memilih customer yang menjadi tanggung jawabnya, baik melalui penugasan customer maupun penugasan area.

Langkah kedua adalah pemilihan tipe order. Terdapat dua pilihan, yaitu REGULER dan 4P. Tipe order menentukan katalog produk yang ditampilkan pada langkah berikutnya, sehingga sales tidak dapat mencampurkan produk dari tipe order yang berbeda. Pilihan yang sedang aktif ditandai dengan warna dan ikon pemeriksaan.

Langkah ketiga adalah pemilihan produk dan jumlah pesanan. Antarmuka katalog memuat kolom pencarian berdasarkan kode, nama produk, atau supplier, serta kartu produk yang menampilkan nama barang, SKU, harga satuan, satuan, dan jumlah stok tersedia. Sales menentukan jumlah melalui kolom kuantitas atau tombol tambah dan kurang. Pada setiap item, sales dapat membuka panel diskon tiga lapis, menambahkan up price, atau menandai sejumlah kuantitas sebagai barang gratis. Nilai diskon dapat berupa persentase atau nominal, dengan batas maksimum sesuai nilai item. Produk yang stoknya tidak mencukupi atau tidak tersedia tetap ditandai agar sales dapat memilih produk pengganti.

Langkah keempat adalah review order. Antarmuka ini menampilkan ringkasan toko, tipe order, daftar item beserta kuantitas, harga, diskon, up price, dan subtotal, kemudian dilanjutkan dengan total keseluruhan. Terdapat kolom catatan opsional untuk menyampaikan informasi tambahan kepada admin. Pada bagian bawah terdapat dua tombol, yaitu Simpan Draft dan Kirim Order. Simpan Draft digunakan apabila order belum ingin diajukan, sedangkan Kirim Order mengubah status order menjadi menunggu persetujuan. Setelah proses berhasil, sistem menampilkan notifikasi dan mengembalikan pengguna ke halaman sebelumnya, kemudian order langsung muncul pada daftar pesanan. Tampilan alur pembuatan order ditunjukkan pada Gambar 3.7 sampai dengan Gambar 3.10.

### c. Antarmuka Pengajuan Customer Baru

Sales dapat mengajukan customer baru apabila toko yang akan dikunjungi belum terdaftar. Formulir pengajuan terdiri atas dua bagian. Bagian pertama adalah identitas pelanggan yang memuat nama langganan atau outlet, nomor ID atau KTP, alamat KTP, nama kontak atau pemilik, nomor telepon atau HP, alamat kirim, propinsi, kecamatan, kota, kelurahan, serta area atau route. Bagian kedua adalah kode area yang dipilih dari daftar kode area yang sudah ada, dengan pilihan "Lainnya" untuk mengetik kode area baru secara manual.

Nama langganan atau outlet merupakan kolom wajib, sedangkan kolom lain bersifat opsional namun dianjurkan untuk melengkapi data customer. Pada bagian atas formulir terdapat pilihan mode pengajuan, yaitu mengajukan customer saja atau mengajukan customer sekaligus melanjutkan ke pembuatan order. Apabila mode kedua dipilih, setelah pengajuan berhasil sistem langsung membuka alur pembuatan order. Sebelum data dikirim, sistem menampilkan konfirmasi yang memuat ringkasan data customer. Hasil pengajuan kemudian dapat dipantau pada halaman Status Pengajuan Saya yang menampilkan status menunggu, disetujui, atau ditolak beserta alasannya. Tampilan formulir pengajuan customer ditunjukkan pada Gambar 3.11.

### d. Antarmuka Pengelolaan Data oleh Admin

Aplikasi admin web menyediakan beberapa antarmuka masukan yang digunakan untuk mengelola operasional sistem. Seluruh formulir pada aplikasi ini menggunakan pola yang sama, yaitu judul formulir, kelompok kolom, tombol Batal, dan tombol Simpan. Kolom yang wajib diisi ditandai dengan tanda bintang, sedangkan kesalahan pengisian ditampilkan tepat di bawah kolom yang bersangkutan.

Pada menu Pesanan, ADMIN dapat menyetujui atau menolak pesanan yang berstatus menunggu, sedangkan SUPERVISOR dan MANAGER hanya dapat memantau karena halaman tersebut bersifat baca saja bagi kedua peran itu. Persetujuan dilakukan melalui dialog konfirmasi, sedangkan penolakan memerlukan alasan penolakan yang bersifat opsional. ADMIN juga dapat menyunting diskon tiga lapis dan up price pada setiap item, membatalkan sebagian atau seluruh kuantitas item beserta alasannya, serta melepas draft agar dapat dilanjutkan oleh sales. Perubahan tersebut secara otomatis menyesuaikan total order dan tercatat pada riwayat.

Pada menu Produk & Stok, admin dapat mencari dan menyaring produk berdasarkan supplier, status stok, dan tipe order. Produk baru ditambahkan melalui menu Sinkronisasi, sedangkan menu ini digunakan untuk memantau produk yang sudah ada. Formulir penyuntingan produk memuat kategori, satuan, supplier, dan tipe order, sementara nama barang, SKU, dan harga ditampilkan sebagai identitas produk. Perubahan stok dilakukan melalui dialog yang menampilkan stok booking, stok diterima, dan stok tersedia sebagai pembanding, sehingga admin dapat menetapkan stok sistem baru dengan angka yang valid dan tidak negatif. Pada menu Supplier, admin dapat menambah supplier, mengaktifkan atau menonaktifkan supplier, serta mengubah tipe order yang melekat pada supplier tersebut.

Pada menu Toko dan Pengajuan Customer, admin dapat menyunting data toko serta memproses pengajuan customer yang dikirim sales. Persetujuan pengajuan memerlukan kode langganan dan dapat disertai penyesuaian nama toko atau alamat, sedangkan penolakan dapat disertai alasan yang akan ditampilkan kepada sales. Setelah disetujui, data pengajuan berubah menjadi customer resmi dan dapat dipilih pada pembuatan order.

Pada menu User, supervisor dan manager dapat menambahkan serta menyunting akun pengguna. Formulir memuat username, password, nama, role, cabang, dan status aktif. Username harus unik, password wajib diisi pada saat pembuatan akun, dan role menentukan menu yang dapat diakses. Pada menu Penugasan Sales, terdapat tiga sudut pandang pengelolaan, yaitu per area, per customer, dan per sales. Supervisor dan manager dapat memilih area atau customer kemudian menetapkan sales yang bertanggung jawab, atau memilih sales terlebih dahulu lalu menentukan cakupan tugasnya.

Pada menu Performa Sales, supervisor atau manager dapat menetapkan target penjualan per sales untuk periode berjalan. Formulir target memuat tipe target, yaitu jumlah order atau nilai revenue, nilai target, dan nominal insentif. Target supplier ditetapkan melalui dialog terpisah yang memuat nama supplier, periode, dan nilai target dalam rupiah. Pada menu Bulletin, admin membuat pengumuman dengan judul, deskripsi, tautan atau unggahan file PDF, masa berlaku, dan cakupan cabang. Apabila masa berlaku dikosongkan, bulletin dianggap berlaku tanpa batas waktu.

Pada menu Sinkronisasi, admin mengimpor data produk dan data customer dari file Excel berformat `.xlsx`. Antarmuka impor memuat tombol pemilihan file, nama file yang dipilih, tombol unggah, serta ringkasan hasil impor. Setelah proses selesai, sistem menampilkan jumlah data yang diproses, jumlah data baru, jumlah data yang diperbarui, dan jumlah data yang dilewati. Tampilan antarmuka pengelolaan data pada aplikasi admin web ditunjukkan pada Gambar 3.12 sampai dengan Gambar 3.15, sedangkan ringkasan antarmuka masukan beserta field utamanya ditunjukkan pada Tabel 3.19.

**Tabel 3.19 Ringkasan Antarmuka Masukan dan Field Utama**

| No | Antarmuka | Field atau Komponen Masukan | Ketentuan |
|---:|---|---|---|
| 1 | Login | Username, password | Keduanya wajib; akun harus aktif. |
| 2 | Ganti password | Password lama, password baru, konfirmasi | Password baru harus sama dengan konfirmasi. |
| 3 | Order langkah 1 | Pencarian toko, pilihan customer, tombol ajukan customer | Customer harus termasuk cakupan sales. |
| 4 | Order langkah 2 | Pilihan REGULER atau 4P | Hanya satu tipe order untuk setiap order. |
| 5 | Order langkah 3 | Pencarian produk, kuantitas, diskon, up price, barang gratis | Kuantitas minimal satu dan tidak melebihi stok tersedia. |
| 6 | Order langkah 4 | Catatan, tombol Simpan Draft, tombol Kirim Order | Minimal satu item harus dipilih sebelum masuk ke review. |
| 7 | Pengajuan customer | Nama outlet, nomor ID/KTP, alamat, kontak, telepon, wilayah, kode area, mode pengajuan | Nama outlet wajib; kode area dipilih dari daftar atau diisi manual. |
| 8 | Persetujuan pengajuan customer | Kode langganan, nama toko, alamat, alasan penolakan | Kode langganan wajib diisi saat menyetujui pengajuan. |
| 9 | Persetujuan pesanan | Tombol Setujui, tombol Tolak, alasan penolakan | Penolakan hanya untuk pesanan berstatus menunggu. |
| 10 | Penyuntingan item | Diskon tiga lapis, up price, kuantitas pembatalan, alasan pembatalan | Nilai diskon tidak melebihi nilai item; kuantitas pembatalan tidak melebihi kuantitas item. |
| 11 | Produk & stok | Kategori, satuan, supplier, tipe order, stok sistem | Stok berupa angka tidak negatif dan diubah melalui dialog terpisah. |
| 12 | Supplier | Nama supplier, status aktif, tipe order | Nama supplier wajib dan tidak boleh duplikat. |
| 13 | User | Username, password, nama, role, cabang, status aktif | Username unik; role menentukan hak akses. |
| 14 | Penugasan sales | Area, customer, sales | Satu area atau customer dapat ditugaskan kepada sales tertentu. |
| 15 | Target | Tipe target, nilai target, insentif, supplier | Nilai target dan insentif berupa angka. |
| 16 | Bulletin | Judul, deskripsi, URL atau file PDF, masa berlaku, cabang | Judul wajib; file berformat PDF. |
| 17 | Impor Excel | File `.xlsx`, tombol unggah | Hanya file Excel dengan susunan kolom yang sesuai. |

Seluruh masukan pada sistem melewati dua lapis pemeriksaan, yaitu validasi pada antarmuka dan validasi pada server. Validasi antarmuka bertujuan memberikan koreksi secara langsung, misalnya menolak huruf pada kolom angka atau menandai kolom wajib yang belum diisi. Validasi server memastikan data tetap konsisten walaupun permintaan dikirim di luar aplikasi, termasuk memeriksa keunikan username, ketersediaan stok, kesesuaian cabang, dan peralihan status order yang sah.

## 3.4.2 Perancangan Antarmuka Keluaran Sistem

Antarmuka keluaran menyajikan hasil pengolahan data kepada pengguna. Keluaran sistem ini terdiri atas ringkasan pada halaman utama, daftar dan detail transaksi, laporan dalam bentuk tabel dan berkas Excel, serta riwayat proses  impor. Penyajian keluaran disesuaikan dengan kebutuhan pengguna; sales memerlukan informasi yang singkat dan mudah dibaca di ponsel, sedangkan admin dan manager memerlukan tabel yang lengkap untuk analisis.

### a. Antarmuka Beranda Aplikasi Sales

Beranda merupakan halaman pertama yang ditampilkan setelah sales login. Bagian atas halaman memuat sapaan kepada pengguna, kemudian dilanjutkan dengan tiga kartu ringkasan yang menunjukkan omzet hari ini beserta jumlah order yang disetujui, jumlah order yang masih menunggu beserta nilainya, serta pencapaian target bulan ini beserta insentif yang diperoleh. Di bawah kartu ringkasan terdapat bagian Orderan Terbaru yang menampilkan beberapa pesanan terakhir beserta statusnya. Promo dan bulletin tidak ditampilkan pada beranda, tetapi dapat dibuka melalui menu Lainnya. Seluruh angka pada beranda diambil dari data yang sama dengan daftar pesanan, sehingga sales tidak perlu membuka halaman lain untuk mengetahui posisi pekerjaannya. Tampilan beranda aplikasi sales ditunjukkan pada Gambar 3.16.

### b. Antarmuka Daftar dan Detail Pesanan

Halaman Pesanan menampilkan daftar order milik sales. Bagian atas memuat kolom pencarian berdasarkan nomor order atau nama toko dan deretan filter status, yaitu Semua, Draft, Menunggu, Disetujui, dan Ditolak. Setiap kartu pesanan menampilkan nomor order, nama toko, tanggal, jumlah item, total nilai, dan label status berwarna. Daftar dimuat secara bertahap ketika pengguna menggulir halaman, dan dapat diperbarui dengan tarik ke bawah. Tampilan daftar pesanan ditunjukkan pada Gambar 3.17.

Halaman detail pesanan menampilkan informasi yang lebih lengkap, yaitu status pesanan pada bagian paling atas, tanggal, tipe order, data toko berupa nama dan alamat, daftar item beserta kuantitas, harga satuan, diskon, up price, dan subtotal, serta total order dan catatan. Apabila pesanan ditolak, alasan penolakan ditampilkan pada banner khusus. Apabila terdapat item yang dibatalkan, item tersebut ditampilkan pada bagian terpisah beserta kuantitas dan alasannya. Tombol tindakan pada halaman ini menyesuaikan status, misalnya melanjutkan draft atau mengirim ulang draft yang belum diajukan. Tampilan detail pesanan ditunjukkan pada Gambar 3.18.

### c. Antarmuka Katalog Produk

Katalog menampilkan produk yang tersedia untuk cabang sales. Setiap kartu produk memuat nama barang, SKU, supplier, harga, satuan, dan jumlah stok tersedia, dengan label status Tersedia, Stok Rendah, atau Habis. Pengguna dapat mencari produk berdasarkan nama atau SKU, menyaring berdasarkan status stok, serta memilih kategori melalui daftar pilihan. Apabila kartu produk dibuka, sistem menampilkan rincian produk termasuk kategori dan informasi stok. Apabila filter aktif, jumlah filter ditampilkan pada tombol filter dan tersedia tombol untuk mengembalikan tampilan ke kondisi awal. Katalog ini bersifat baca saja; perubahan stok hanya dapat dilakukan melalui aplikasi admin. Tampilan katalog produk ditunjukkan pada Gambar 3.19.

### d. Antarmuka Dashboard Admin

Dashboard admin menampilkan ringkasan kondisi sistem pada tanggal yang dipilih. Terdapat sembilan kartu statistik, yaitu Total Pesanan, Menunggu Persetujuan, Disetujui, Ditolak, Dibatalkan, Total Produk, Total Toko, Draft Pesanan, dan Produk Perlu Tinjau. Di bawah kartu statistik terdapat daftar pesanan yang menunggu persetujuan agar admin dapat segera memprosesnya, serta bagian Ambil Laporan yang menjadi pintu masuk untuk mengunduh laporan harian dan laporan periode. Tanggal laporan dapat diubah melalui pemilih tanggal, dan data pada dashboard akan mengikuti tanggal tersebut. Untuk SUPERVISOR dan MANAGER, dashboard dilengkapi ringkasan total seluruh cabang dan performa sales, sedangkan MANAGER memperoleh tambahan rincian per cabang. Tampilan dashboard admin ditunjukkan pada Gambar 3.12.

### e. Antarmuka Laporan Harian dan Laporan Periode

Laporan harian dan laporan periode dihasilkan dalam bentuk berkas Excel berformat `.xlsx` yang dapat diunduh melalui peramban. Laporan harian memuat seluruh item order pada satu tanggal, sedangkan laporan periode memuat item order pada rentang tanggal yang dipilih. Rentang tanggal maksimal 365 hari dan tanggal akhir tidak boleh lebih awal daripada tanggal mulai. Sebelum mengunduh, pengguna dapat memilih status order yang akan disertakan, yaitu Disetujui, Menunggu, Ditolak, atau Semua Status, dengan nilai awal Disetujui. Nama berkas yang diunduh menggunakan pola `laporan-harian-TANGGAL.xlsx` atau `laporan-periode-TANGGAL-AWAL-sd-TANGGAL-AKHIR.xlsx`.

Setiap baris pada laporan mewakili satu item order, sehingga satu order dapat menghasilkan beberapa baris apabila memiliki lebih dari satu produk. Susunan kolom laporan ditunjukkan pada Tabel 3.20.

**Tabel 3.20 Susunan Kolom Laporan Penjualan**

| No | Nama Kolom | Keterangan |
|---:|---|---|
| 1 | Tanggal | Tanggal order dalam format tahun-bulan-hari. |
| 2 | Cabang | Kode cabang tempat order dibuat. |
| 3 | Kode Pelanggan | Kode customer yang terdaftar. |
| 4 | Nama Pelanggan | Nama toko atau outlet. |
| 5 | Kode Item | SKU produk. |
| 6 | Nama Item | Nama barang. |
| 7 | Qty | Jumlah produk yang dipesan. |
| 8 | Satuan | Satuan produk, misalnya pcs atau dus. |
| 9 | Harga Satuan | Harga produk per satuan. |
| 10 | Total Harga Sebelum Diskon | Hasil perkalian harga satuan dengan kuantitas. |
| 11 | Diskon Layer 1 | Nilai potongan diskon lapis pertama. |
| 12 | Diskon Layer 2 | Nilai potongan diskon lapis kedua. |
| 13 | Diskon Layer 3 | Nilai potongan diskon lapis ketiga. |
| 14 | Total Diskon | Jumlah seluruh potongan diskon. |
| 15 | Up Price | Nilai penyesuaian harga ke atas. |
| 16 | Total Harga Setelah Diskon | Nilai akhir item setelah diskon dan up price. |
| 17 | Tipe Order | REGULER atau 4P. |
| 18 | Nama Sales | Nama sales pembuat order. |
| 19 | Supplier | Nama supplier pemasok produk. |

### f. Antarmuka Performa Sales dan Supplier

Halaman Performa Sales digunakan supervisor dan manager untuk mengevaluasi kinerja penjualan. Bagian atas halaman memuat filter cabang, filter periode, dan pilihan rentang tanggal khusus. Manager dapat memilih seluruh cabang atau satu cabang tertentu, sedangkan pengguna lain mengikuti cabangnya masing-masing. Halaman ini menampilkan KPI per supplier, leaderboard sales, serta tabel target dan insentif.

KPI per supplier menampilkan nama supplier, target, realisasi penjualan, dan persentase pencapaian. Leaderboard menampilkan peringkat sales beserta jumlah order, revenue, dan jumlah pengajuan customer. Tabel target dan insentif memuat nama sales, tipe target, nilai target, insentif, dan tombol untuk menetapkan atau menyunting target. Setiap baris dapat diberi penanda tambahan, misalnya Non-Aktif untuk sales yang tidak aktif atau produk dengan tipe order 4P, sehingga manager dapat menafsirkan capaian secara tepat. Tampilan halaman performa sales ditunjukkan pada Gambar 3.20.

### g. Antarmuka Laporan Lintas Cabang

Laporan Lintas Cabang hanya tersedia untuk MANAGER global dan terdiri atas dua tab, yaitu Penjualan dan Stok. Tab Penjualan menampilkan kartu total seluruh cabang yang memuat jumlah order disetujui, order menunggu, omzet, jumlah customer, dan jumlah sales, kemudian dilanjutkan dengan kartu ringkasan untuk setiap cabang. Tab Stok menampilkan jumlah SKU, nilai stok, dan jumlah produk dengan stok rendah pada setiap cabang. Data pada kedua tab mengikuti periode bulan berjalan dan dapat diperbarui dengan tarik ke bawah. Tampilan laporan lintas cabang ditunjukkan pada Gambar 3.21.

### h. Antarmuka Hasil Impor dan Riwayat Error

Setelah proses impor produk atau customer selesai, sistem menampilkan kartu hasil impor yang memuat total data yang diproses, jumlah data baru, jumlah data yang diperbarui, dan jumlah data yang dilewati. Di bawahnya terdapat bagian Histori Import yang menampilkan daftar proses impor sebelumnya, meliputi jenis impor, nama berkas, waktu proses, dan ringkasan hasil. Bagian Riwayat Error menampilkan baris data yang gagal diproses beserta nomor baris, kode produk, dan alasan kegagalan, sehingga admin dapat memperbaiki berkas dan mengunggahnya kembali. Apabila tidak ada kesalahan, sistem menampilkan pesan bahwa seluruh baris berhasil diproses, dan tersedia tombol untuk membersihkan riwayat error setelah data diperbaiki. Tampilan hasil impor ditunjukkan pada Gambar 3.22.

### i. Antarmuka Bulletin dan Promo

Bulletin ditampilkan pada aplikasi sales dalam bentuk daftar kartu yang memuat judul, deskripsi, masa berlaku, dan tombol Lihat PDF apabila lampiran tersedia. Halaman ini dapat menampilkan promo yang sedang berlangsung atau seluruh promo termasuk yang sudah berakhir. Setiap bulletin dapat ditutup oleh sales, dan penutupan tersebut dicatat sehingga bulletin yang sama tidak muncul kembali. Tampilan bulletin dan promo ditunjukkan pada Gambar 3.23. Ringkasan antarmuka keluaran beserta bentuk penyajiannya ditunjukkan pada Tabel 3.21.

**Tabel 3.21 Ringkasan Antarmuka Keluaran Sistem**

| No | Antarmuka | Informasi yang Ditampilkan | Bentuk Penyajian |
|---:|---|---|---|
| 1 | Beranda sales | Omzet hari ini, order menunggu, capaian target, order terbaru | Kartu ringkasan dan daftar |
| 2 | Daftar pesanan | Nomor order, toko, tanggal, total, status | Kartu dengan filter dan pencarian |
| 3 | Detail pesanan | Status, tanggal, tipe order, toko, item, diskon, up price, total, catatan, alasan penolakan | Halaman rincian |
| 4 | Katalog produk | Nama, SKU, kategori, harga, stok, status ketersediaan | Kartu produk dan filter |
| 5 | Dashboard admin | Sembilan indikator pesanan dan data master, daftar pesanan menunggu | Kartu statistik dan daftar |
| 6 | Laporan harian dan periode | Rincian item order per tanggal atau rentang tanggal | Berkas Excel `.xlsx` |
| 7 | Performa sales | KPI supplier, peringkat sales, target, insentif | Kartu dan tabel |
| 8 | Laporan lintas cabang | Ringkasan penjualan dan stok seluruh cabang | Tab dan kartu per cabang |
| 9 | Hasil impor | Jumlah data diproses, ditambah, diperbarui, dilewati, riwayat error | Kartu ringkasan dan tabel |
| 10 | Bulletin dan promo | Judul, deskripsi, masa berlaku, lampiran PDF | Daftar kartu |
| 11 | Pengajuan customer | Data pengajuan, status, alasan penolakan | Daftar dan halaman detail |

Secara keseluruhan, antarmuka keluaran menggunakan pola penyajian yang seragam, yaitu ringkasan dalam bentuk kartu untuk informasi utama, tabel untuk data rinci, label berwarna untuk status, dan berkas Excel untuk kebutuhan pelaporan. Pola ini memudahkan pengguna berpindah antarhalaman karena posisi informasi penting, warna status, dan bentuk tombol tetap konsisten. Dengan demikian, perancangan antarmuka pada sistem ini tidak hanya memperhatikan tampilan, tetapi juga keterkaitan antara masukan yang dilakukan pengguna dan keluaran yang dihasilkan sistem.

---

*Catatan: nomor gambar (Gambar 3.6 sampai Gambar 3.23) dan nomor tabel (Tabel 3.18 sampai Tabel 3.21) mengikuti urutan gambar dan tabel sebelumnya. Silakan sesuaikan bila jumlah gambar pada bab sebelumnya berbeda.*

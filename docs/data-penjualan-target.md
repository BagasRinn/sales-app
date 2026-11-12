# Target omzet Data Penjualan

Target pada kartu **Sales Teratas** dan **Supplier Teratas** di halaman Data
Penjualan diimpor dari workbook terpisah dari laporan penjualan. File ini hanya
dipakai untuk visualisasi target pada dashboard Data Penjualan; tidak mengubah
target di halaman Performa Sales atau Supplier.

## Format workbook

Simpan sebagai `.xlsx` atau `.xls` dengan ukuran maksimal 10 MB. Workbook dapat
memuat satu atau kedua sheet berikut; urutan sheet tidak berpengaruh:

| Sheet | Kolom wajib |
|---|---|
| Target Sales | Cabang, Periode, Sales (atau Nama Sales / Nama Salesman / Salesman), Target |
| Target Supplier | Cabang, Periode, Supplier (atau Nama Supplier / Last Supplier / Supplier Name), Target |

Kolom dikenali dari nama header, bukan urutan kolom. Header boleh berada di
antara 200 baris pertama. Alias umum yang diterima:

- Cabang: `Cabang`, `Branch`, `Kode Cabang`
- Periode: `Periode`, `Period`, `Bulan`, `Periode (YYYY-MM)`, `Periode Penjualan`
- Sales: `Sales`, `Nama Sales`, `Nama Salesman`, `Salesman`
- Supplier: `Supplier`, `Nama Supplier`, `Last Supplier`, `Supplier Name`
- Target: `Target`, `Target Omzet`, `Target Penjualan`, `Target Revenue`, `Nilai Target`

Sheet generik dengan kolom `Entitas` dikenali bila nama sheet mengandung
`Sales` atau `Supplier`.

Contoh:

| Cabang | Periode | Sales | Target Omzet |
|---|---|---|---:|
| BANJARMASIN | 2026-09 | Yusuf Hidayat | 2000000000 |

`Periode` menerima `YYYY-MM`, bentuk tahun/bulan seperti `2026/9`, atau nilai
tanggal. Cabang harus berupa kode cabang aktif atau nama cabang yang dikenal.
Nilai target harus berupa bilangan bulat rupiah non-negatif; angka nol diterima.
Baris kosong dilewati, sedangkan baris tidak valid dihitung sebagai dilewati
dan dilaporkan dengan sheet, nomor baris, serta alasan (maksimal 50 detail).

## Impor dan pencocokan

Tombol **Import Target** hanya tersedia untuk MANAGER global di tab Data
Penjualan. Import melakukan upsert berdasarkan cabang, periode, jenis target,
dan nama yang dinormalisasi. Normalisasi mengubah nama menjadi huruf kapital,
mengganti tanda baca dengan spasi, dan merapatkan spasi. Contohnya,
`CANDRA FOOD, CV` cocok dengan `Candra Food CV`.

Nilai target yang sama tidak menulis ulang baris. Perubahan nilai atau nama
tampilan memperbarui baris yang ada. Upload tidak menghapus target yang tidak
terdapat pada file; koreksi dilakukan dengan mengimpor nilai yang benar.
Hasil import mencantumkan jumlah baris, baru, diperbarui, dilewati, dan hasil
per sheet. Setiap import dicatat pada `import_logs` dengan tipe
`SALES_TARGETS`.

## Tampilan

Realisasi omzet NET (penjualan dikurangi retur) pada periode yang dipilih
dibagi target omzet untuk sales atau supplier yang namanya cocok. Target
supplier dijumlahkan lintas cabang pada scope GLOBAL; filter satu cabang
menampilkan target cabang tersebut.
Rentang 3/6/12 bulan menjumlahkan target pada seluruh bulan di rentang.

Bar target selalu berdasarkan omzet, termasuk saat ranking diubah ke mode
Margin. Isian tanpa target menampilkan `Target belum di-set`; target nol
menampilkan bahwa progres tidak dapat dihitung. Bar dibatasi 100%, sementara
teks menampilkan persentase realisasi sebenarnya, termasuk nilai di atas 100%.

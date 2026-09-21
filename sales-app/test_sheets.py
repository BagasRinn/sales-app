import gspread

# Menggunakan file JSON untuk otentikasi
try:
    gc = gspread.service_account(filename='credentials.json')
    
    sh = gc.open('Test-sheets')
    
    # 3. Mengakses sheet pertama (Sheet1)
    worksheet = sh.sheet1
    
    # 4. Melakukan uji coba menulis data ke sel A1
    worksheet.update_acell('A1', 'Koneksi API Sukses!')
    
    print(f"Berhasil terhubung ke Spreadsheet: {sh.title}")
    print("Silakan cek Google Sheets Anda, sel A1 seharusnya sudah terisi.")

except Exception as e:
    print(f"Terjadi kesalahan: {e}")
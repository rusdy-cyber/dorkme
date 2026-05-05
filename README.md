# dorkme
simpel google dorking 
Cara Pakai & Apa yang Membuatnya “Super Power”

1. Simpan script, beri izin eksekusi:
   ```bash
   chmod +x cf_bypass_dork.sh
   ```
2. Jalankan dengan domain target:
   ```bash
   ./cf_bypass_dork.sh -d example.com -t 8 -o hasil_bypass
   ```
3. Otomatis terjadi:
   · Script akan menghasilkan 40+ dork yang spesifik untuk menggali informasi dari balik Cloudflare.
   · Semua pencarian Google dijalankan paralel.
   · Setiap URL hasil dicek header respons-nya. Jika tidak ada tanda Cloudflare (cf-ray, Server: cloudflare), URL tersebut dianggap sebagai origin/backend tanpa proteksi → disimpan di bypass_urls.txt.
   · Halaman-halaman itu juga di-scan untuk mengekstrak alamat IP yang mungkin muncul (phpinfo, error message, dsb) → disimpan di possible_origin_ips.txt.
   

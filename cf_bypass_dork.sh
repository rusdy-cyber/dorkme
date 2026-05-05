#!/usr/bin/env bash
# ============================================================
# 🔥 SUPER DORK - CLOUDFLARE BYPASS / FIRE CLOUD PENETRATION
# ============================================================
# Hanya untuk bug bounty, aset sendiri, atau pentest resmi.
# ============================================================

set -euo pipefail

# ---------- warna ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------- banner ----------
banner() {
    echo -e "${RED}"
    echo "  ███████╗██╗██████╗ ███████╗     ██████╗██╗      ██████╗ ██╗   ██╗██████╗ "
    echo "  ██╔════╝██║██╔══██╗██╔════╝    ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗"
    echo "  █████╗  ██║██████╔╝█████╗      ██║     ██║     ██║   ██║██║   ██║██║  ██║"
    echo "  ██╔══╝  ██║██╔══██╗██╔══╝      ██║     ██║     ██║   ██║██║   ██║██║  ██║"
    echo "  ██║     ██║██║  ██║███████╗    ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝"
    echo "  ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝     ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ "
    echo -e "${NC}"
    echo -e "${YELLOW}        SUPER POWER DORKING - CLOUDFLARE / FIRE CLOUD BYPASS${NC}"
    echo
}

# ---------- usage ----------
usage() {
    echo "Usage: $0 -d <domain> [-t threads] [-o output_dir]"
    echo "  -d  Domain target (contoh: example.com)"
    echo "  -t  Jumlah pencarian paralel (default: 5)"
    echo "  -o  Direktori output (default: ./bypass_results/<domain>)"
    exit 1
}

# ---------- dependensi ----------
check_deps() {
    for cmd in googler curl; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}[!] $cmd tidak ditemukan. Install: sudo apt install googler curl${NC}"
            exit 1
        fi
    done
}

# ---------- cek apakah URL di belakang Cloudflare ----------
is_cloudflare() {
    local url="$1"
    local headers
    headers=$(curl -sI --max-time 6 "$url" 2>/dev/null || true)
    if echo "$headers" | grep -qi "cf-ray\|server: cloudflare"; then
        return 0   # yes, Cloudflare detected
    else
        return 1   # no Cloudflare (possible origin / bypass)
    fi
}

# ---------- ekstrak IP dari konten halaman (jika ada) ----------
extract_ip() {
    local url="$1"
    local body
    body=$(curl -sk --max-time 6 "$url" 2>/dev/null || true)
    # Cari pola IP sederhana, juga filter IPv4
    echo "$body" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | while read ip; do
        # Abaikan IP lokal
        if [[ "$ip" != 127.* && "$ip" != 0.* && "$ip" != 10.* && "$ip" != 172.16.* && "$ip" != 192.168.* ]]; then
            echo "$ip"
        fi
    done
}

# ---------- proses satu dork ----------
process_dork() {
    local dork="$1"
    local output_base="$2"
    local outfile="${output_base}/urls_$(echo "$dork" | md5sum | cut -d' ' -f1).txt"

    echo -e "${BLUE}[DORK]${NC} $dork"
    googler --np -n 30 -C "$dork" 2>/dev/null | grep -Eo 'https?://[^ ]+' | sort -u > "$outfile" || true

    local count=$(wc -l < "$outfile")
    echo -e "${YELLOW}  -> Mendapat $count URL${NC}"

    while IFS= read -r url; do
        if is_cloudflare "$url"; then
            echo -e "${RED}[CF]${NC} $url"  >> "$OUTDIR/cloudflare_urls.txt"
        else
            echo -e "${GREEN}[BYPASS - NO CF]${NC} $url"
            echo "$url" >> "$OUTDIR/bypass_urls.txt"

            # Cek apakah ada IP di dalam halaman
            local ips
            ips=$(extract_ip "$url")
            if [[ -n "$ips" ]]; then
                echo "$url : $ips" >> "$OUTDIR/possible_origin_ips.txt"
            fi
        fi
    done < "$outfile"
}

# ---------- menghasilkan daftar dork otomatis untuk domain ----------
generate_dorks() {
    local domain="$1"
    local dork_file="$2"
    # Bersihkan protokol jika ada
    domain=$(echo "$domain" | sed 's|https\?://||; s|/.*||')

    cat > "$dork_file" <<EOF
# ---- Subdomain tanpa www (sering tanpa Cloudflare) ----
site:$domain -www
site:*.$domain -www

# ---- Direktori terbuka & file backup ----
site:$domain intitle:"index of"
site:$domain inurl:backup
site:$domain ext:sql | ext:env | ext:log
site:$domain "index of" "parent directory"

# ---- File konfigurasi & kredensial ----
site:$domain inurl:wp-config.php
site:$domain inurl:config.xml
site:$domain inurl:.env
site:$domain inurl:phpinfo.php
site:$domain inurl:server-status
site:$domain inurl:server-info

# ---- Potensi origin IP leak melalui header atau halaman ----
site:$domain intitle:"phpinfo()"
site:$domain "Server at" intext:"Server at"
site:$domain "X-Forwarded-For"

# ---- Teknologi / stack yang mungkin membeberkan IP ----
site:$domain "Welcome to nginx" -"cloudflare"
site:$domain "Apache Server at"
site:$domain intext:"Your IP:"

# ---- Subdomain development / staging ----
site:*.$domain intitle:"staging"
site:*.$domain intitle:"dev"
site:*.$domain intitle:"test"
site:$domain inurl:dev
site:$domain inurl:staging

# ---- File sensitif lainnya ----
site:$domain ext:json "password"
site:$domain ext:yaml "api_key"
site:$domain ext:txt "password"
EOF
    echo -e "${YELLOW}[*] Dork otomatis untuk $domain dibuat ($dork_file)${NC}"
}

# ---------- MAIN ----------
main() {
    banner

    local domain=""
    local threads=5
    local outdir=""

    while getopts "d:t:o:" opt; do
        case $opt in
            d) domain="$OPTARG" ;;
            t) threads="$OPTARG" ;;
            o) outdir="$OPTARG" ;;
            *) usage ;;
        esac
    done

    if [[ -z "$domain" ]]; then
        echo -e "${RED}[!] Domain target harus diberikan${NC}"
        usage
    fi

    check_deps

    # Set output directory
    domain_clean=$(echo "$domain" | sed 's|https\?://||; s|/.*||')
    OUTDIR="${outdir:-./bypass_results/$domain_clean}"
    mkdir -p "$OUTDIR"

    local dork_file="$OUTDIR/auto_dorks.txt"
    generate_dorks "$domain" "$dork_file"

    echo -e "${YELLOW}[*] Memulai dorking pada $domain ($threads thread)${NC}"
    echo -e "[*] Hasil di: $OUTDIR"
    echo

    # Baca dork file, jalankan paralel
    local job_count=0
    while IFS= read -r dork; do
        # Skip baris kosong dan komentar
        [[ -z "$dork" || "$dork" == \#* ]] && continue
        process_dork "$dork" "$OUTDIR" &
        ((job_count++))
        if [[ $job_count -ge $threads ]]; then
            wait -n
            ((job_count--))
        fi
    done < "$dork_file"
    wait

    echo
    echo -e "${GREEN}[+] Dorking selesai.${NC}"
    echo -e "${GREEN}[+] URL yang berhasil bypass Cloudflare: $OUTDIR/bypass_urls.txt${NC}"
    echo -e "${GREEN}[+] Kemungkinan origin IP ditemukan: $OUTDIR/possible_origin_ips.txt${NC}"
    echo -e "${GREEN}[+] Semua URL di belakang Cloudflare: $OUTDIR/cloudflare_urls.txt${NC}"
}

main "$@"

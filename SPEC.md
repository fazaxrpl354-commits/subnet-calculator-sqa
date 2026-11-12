# Spesifikasi Teknis: Kalkulator Subnet & VLSM Berbasis Web

Dokumen ini mendefinisikan spesifikasi teknis dan arsitektur untuk pengembangan aplikasi **Kalkulator Subnet & VLSM Berbasis Web** menggunakan tumpukan teknologi backend **Python 3.12 + FastAPI**, pengujian **pytest**, dan antarmuka satu halaman berbasis HTML/JavaScript.

---

## 1. Tujuan

Membangun dan mendokumentasikan spesifikasi perangkat lunak yang andal, deterministis, dan mudah diuji bagi guru serta siswa SMK TKJ untuk menghitung parameter subnetting IPv4 standar maupun pengalokasian Variable Length Subnet Mask (VLSM) secara akurat tanpa ambiguitas logika.

---

## 2. Aturan Validasi

Seluruh lapisan input harus divalidasi dengan ketat sebelum perhitungan dilakukan:

* **Validasi IP (String):**
* Harus terdiri dari tepat 4 oktet yang dipisahkan oleh tanda titik (`.`).
* Setiap oktet berupa angka bulat desimal dengan rentang nilai **0 hingga 255**.
* **Kasus Tepi Penolakan:** Dilarang memiliki angka `0` di depan (*leading zeros*), contoh: `192.168.01.1` harus ditolak.
* Tidak boleh mengandung spasi, karakter alfabet, atau kosong.


* **Validasi Prefix (Integer / String angka):**
* Berupa bilangan bulat dengan rentang **0 hingga 32**.
* Nilai di luar rentang tersebut (misal: `-1`, `33`) atau non-angka harus ditolak.


* **Penanganan Error:** Setiap pelanggaran aturan validasi pada fungsi logika harus memicu pengecualian `ValueError`, sedangkan pada lapisan API harus merespons dengan HTTP Status `400 Bad Request` dan format JSON `{"detail": "pesan kesalahan"}`.

---

## 3. Kontrak Fungsi (`main.py`)

### A. `hitung_subnet(ip: str, prefix: int) -> dict`

* **Deskripsi:** Menghitung parameter subnet berdasarkan alamat IPv4 dan prefix yang diberikan.
* **Parameter:**
* `ip` (str): Alamat IPv4 string.
* `prefix` (int): Angka prefix dari 0 sampai 32.


* **Return (`dict`):** Mengembalikan kamus dengan kunci:
* `mask`: Subnet mask dalam format desimal bertitik (contoh: `255.255.255.0`).
* `network`: Alamat jaringan (*network address*).
* `broadcast`: Alamat *broadcast* (atau `None` untuk prefix `/31` dan `/32`).
* `first_host`: Alamat host pertama yang dapat digunakan.
* `last_host`: Alamat host terakhir yang dapat digunakan.
* `usable_hosts`: Jumlah total host aktif yang dapat digunakan (integer).


* **Aturan Khusus Perhitungan:**
* **Prefix 0–30:** Jumlah host = $2^{(32 - \text{prefix})} - 2$.
* **Prefix /31 (RFC 3021):** Menggunakan aturan *point-to-point*, jumlah host = 2, `broadcast = None`, `first_host` dan `last_host` adalah kedua IP yang tersedia dalam blok tersebut.
* **Prefix /32:** Host tunggal, `broadcast = None`, `first_host = last_host = IP itu sendiri`, jumlah host = 1 (atau 0/1 tergantung konvensi operasional; disepakati 1 host aktif).
* **Bitwise Operation:** `network = IP_INT & MASK_INT`.



### B. `alokasi_vlsm(network_cidr: str, kebutuhan_host: list[int]) -> list[dict]`

* **Deskripsi:** Mengalokasikan blok subnet secara efisien menggunakan metode VLSM.
* **Parameter:**
* `network_cidr` (str): Alamat jaringan utama dalam format CIDR (misal: `192.168.1.0/24`).
* `kebutuhan_host` (list[int]): Daftar integer kebutuhan host tiap sub-jaringan.


* **Return (`list[dict]`):** Daftar kamus yang masing-masing memuat `kebutuhan`, `network_cidr`, serta seluruh kunci hasil dari fungsi `hitung_subnet`.
* **Aturan Khusus VLSM:**
* Urutkan daftar `kebutuhan_host` dari nilai yang terbesar ke terkecil.
* Alokasikan berurutan mulai dari alamat network induk terkecil.
* Ukuran blok dihitung berdasarkan pangkat 2 terkecil yang memenuhi $\ge \text{kebutuhan} + 2$ (dengan batas minimal prefix `/30` atau blok berukuran 4 IP).
* **Raise ValueError jika:** `network_cidr` tidak valid/bukan alamat network yang benar, daftar kebutuhan kosong atau ada nilai $< 1$, atau total blok IP induk tidak cukup menampung seluruh kebutuhan host.



---

## 4. Kontrak API (FastAPI)

* **`GET /api/subnet?ip=<str>&prefix=<int>`**
* **Parameter Query:** `ip`, `prefix`
* **Respons Sukses (200 OK):** JSON objek berisi hasil pemetaan dari `hitung_subnet`.
* **Respons Gagal (400 Bad Request):** `{"detail": "Deskripsi kesalahan validasi"}`.


* **`POST /api/vlsm`**
* **Payload JSON:**
```json
{
  "network": "192.168.1.0/24",
  "kebutuhan_host": [100, 50, 20, 2]
}

```


* **Respons Sukses (200 OK):** JSON array berisi daftar alokasi subnet hasil `alokasi_vlsm`.
* **Respons Gagal (400 Bad Request):** `{"detail": "Deskripsi kesalahan validasi atau kapasitas"}`.


* **`GET /`**
* **Deskripsi:** Menyajikan antarmuka halaman tunggal (`index.html`).



---

## 5. Halaman Web (`index.html`)

* **Desain & Tata Letak:** Satu halaman antarmuka bersih dengan sistem navigasi tab atau *toggle mode* yang memisahkan antara **Mode Subnet Standar** dan **Mode VLSM**.
* **Interaksi Pengguna:**
* Formulir input yang intuitif untuk memasukkan IP/Prefix atau Network Utama & daftar kebutuhan host.
* Area penampil hasil (*result display*) yang terstruktur dalam bentuk tabel atau kartu informasi yang rapi.
* Penanganan peninjauan error secara visual (menampilkan pesan *error* dengan jelas apabila API mengembalikan status 400).



---

## 6. Tabel Test Case (`test_main.py`)

Berikut adalah matriks kasus uji wajib yang diimplementasikan pada berkas `test_main.py` menggunakan `pytest`:

| No | Kasus / Deskripsi | Input / Parameter | Hasil yang Diharapkan / Status |
| --- | --- | --- | --- |
| 1 | Subnet Standar (/25) | IP: `172.16.5.130`<br>

<br>Prefix: `25` | • Network: `172.16.5.128`<br>

<br>• Broadcast: `172.16.5.255`<br>

<br>• Usable Hosts: `126` |
| 2 | Subnet Kecil P2P (/30) | IP: `10.0.0.0`<br>

<br>Prefix: `30` | • Host Range: `.1` s.d. `.2`<br>

<br>• Broadcast: `10.0.0.3`<br>

<br>• Usable Hosts: `2` |
| 3 | Kasus Tepi /31 (RFC 3021) | IP: `192.168.1.0`<br>

<br>Prefix: `31` | • Point-to-point valid<br>

<br>• Broadcast: `None`<br>

<br>• Usable Hosts: `2` |
| 4 | Kasus Tepi /32 (Host Route) | IP: `192.168.1.5`<br>

<br>Prefix: `32` | • Single host<br>

<br>• Broadcast: `None`<br>

<br>• First/Last Host: `192.168.1.5` |
| 5 | Validasi Error: IP Diluar Range | IP: `256.1.1.1`<br>

<br>Prefix: `24` | Memicu `ValueError` / HTTP 400 |
| 6 | Validasi Error: Leading Zero IP | IP: `192.168.01.1`<br>

<br>Prefix: `24` | Memicu `ValueError` / HTTP 400 |
| 7 | Validasi Error: Format / String Salah | IP: `192.168.1` / `abc`<br>

<br>Prefix: `24` | Memicu `ValueError` / HTTP 400 |
| 8 | Validasi Error: Prefix Ekstrem | IP: `192.168.1.1`<br>

<br>Prefix: `33` atau `-1` | Memicu `ValueError` / HTTP 400 |
| 9 | VLSM Sukses (`192.168.1.0/24`) | Network: `192.168.1.0/24`<br>

<br>Kebutuhan: `[100, 50, 20, 2]` | • Alokasi 4 blok tersusun:<br>

<br>  - /25 (mulai `.0`)<br>

<br>  - /26 (mulai `.128`)<br>

<br>  - /27 (mulai `.192`)<br>

<br>  - /30 (mulai `.224`) |
| 10 | VLSM Gagal (Kapasitas Kurang) | Network: `192.168.1.0/24`<br>

<br>Kebutuhan: `[200, 100]` | Memicu `ValueError` / HTTP 400 (Kapasitas blok tidak muat) |

---

## 7. Di Luar Cakupan (*Out of Scope*)

* Dukungan pengalamatan IPv6.
* Autentikasi pengguna, manajemen basis data persisten (database eksternal), atau sistem multi-tenant.
* Fitur routing dinamik lanjutan (OSPF/BGP simulation) atau konfigurasi perangkat fisik secara langsung (*network automation provisioning*).

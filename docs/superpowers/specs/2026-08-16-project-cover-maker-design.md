# project-cover-maker — Design Spec

**Tanggal:** 2026-08-16
**Status:** Disetujui untuk masuk ke implementation plan

---

## 1. Ringkasan

Sebuah skill portabel untuk agent LLM (claude-code, codex, opencode, antigravity) yang
membuat cover portfolio untuk project **mobile app**. Output-nya 4 file PNG 3200×1800
dengan layout berbeda, dibangun dari screenshot asli app milik user, palet warna yang
diturunkan otomatis dari screenshot tersebut, plus nama project dan tagline.

Renderer-nya adalah satu file HTML yang di-screenshot oleh headless Chrome. Tidak ada
package manager, tidak ada akses jaringan, tidak ada dependency runtime selain browser
Chromium-based yang sudah ada di mesin.

---

## 2. Masalah yang diselesaikan

Developer yang mau memajang project mobile-nya di portfolio (Behance, LinkedIn,
GitHub, CV) butuh satu gambar cover yang rapi. Yang tersedia sekarang: bikin manual di
Figma (lama, butuh skill desain) atau pakai generator template online (hasilnya seragam
dan generik).

Yang bikin cover semacam ini bagus sebenarnya bukan kecanggihan rendering-nya,
melainkan **keputusan**: screenshot mana yang dipilih, urutannya bagaimana, taglinenya
apa, layout mana yang cocok. Semua itu adalah pekerjaan yang memang bisa dikerjakan
LLM dengan baik. Karena itu skill ini menaruh seluruh penilaian di sisi agent, dan
membuat renderer-nya sesederhana dan sedeterministik mungkin.

### Anatomi yang jadi acuan

Tiga contoh cover di `example/` dianalisis dan ternyata punya struktur identik:

| Elemen | cover1 (Jamali) | cover2 (Glowfy) | cover3 (TripMate) |
|---|---|---|---|
| Kanvas | 16:9 | 16:9 | 16:9 |
| Background | flat + dot pattern | gradient mint→teal | gradient + brush shape |
| Mockup | 3 HP center-bottom simetris | ~6 device scattered/bleed | 3 HP overlap, kiri |
| Teks | logo + nama + tagline (center) | wordmark + tagline (kanan) | wordmark + tagline (kanan) |
| Badge | 2 logo kampus | logo sponsor + tech stack + kode tim | logo app |

Kesimpulannya: ini masalah **layout system**, bukan masalah generasi gambar.

---

## 3. Non-goals

Yang secara sadar **tidak** dikerjakan di versi ini:

- **Project non-mobile.** Web, dashboard, CLI, ML, backend tidak didukung. Frame device
  hanya phone. Perluasan ke web/laptop frame adalah project terpisah.
- **AI image generation.** Tidak ada pemanggilan model image-gen. Alasannya portabilitas
  (codex/opencode tidak punya akses yang sama), determinisme, dan biaya. Arsitekturnya
  disiapkan supaya bisa ditambahkan nanti: lapisan background adalah layer CSS terpisah
  yang bisa ditukar jadi PNG tanpa mengubah bagian lain.
- **Navigasi app otomatis oleh agent.** Lihat §9.2.
- **Visual regression test berbasis perbandingan pixel.** Lihat §11.
- **Editor interaktif / preview live.** User memilih dari 4 hasil, lalu meminta perubahan
  lewat percakapan biasa.

---

## 4. Keputusan arsitektur

### 4.1 Renderer: HTML/CSS + headless Chrome

Cover adalah satu halaman HTML. Background berupa gradient CSS, device frame berupa
elemen CSS (rounded rect + notch + shadow), screenshot user masuk sebagai `<img>`, teks
memakai font yang di-embed. Render lewat:

```
chrome --headless=new --screenshot=out.png \
       --window-size=3200,1800 \
       --virtual-time-budget=8000 \
       --hide-scrollbars \
       --force-device-scale-factor=1 \
       "file:///.../cover-output/render-split-right.html"
```

### 4.1.1 Halaman render harus self-contained penuh

**Ini bukan preferensi, ini syarat teknis.** Halaman yang dibuka lewat `file://` di Chrome
punya opaque origin, yang menimbulkan tiga hambatan sekaligus:

1. `canvas.getImageData()` atas gambar ber-URL `file://` melempar `SecurityError` karena
   canvas-nya dianggap *tainted*. Ini akan mematikan seluruh ekstraksi palet (§8.5).
2. `fetch('cover.json')` dari halaman `file://` diblokir.
3. `@font-face` dengan sumber `file://` sering ditolak Chrome.

Ketiganya bisa ditambal dengan flag `--allow-file-access-from-files`, tapi flag itu bisa
dimatikan oleh policy enterprise dan sifatnya menambah permukaan risiko. Pendekatan yang
dipakai: **hilangkan seluruh resource eksternal**, sehingga tidak ada yang perlu diambil
lintas origin.

| Resource | Cara masuk ke halaman | Kapan di-embed |
|---|---|---|
| Screenshot & logo & badge | data URI base64 | saat render, oleh render script |
| `cover.json` | di-inject sebagai literal JS menggantikan placeholder `__COVER_DATA__` | saat render, oleh render script |
| Font woff2 | data URI base64 di dalam `cover.css` | sekali, di-commit ke repo |
| SVG dekorasi | markup inline sebagai string di `cover.js` | sekali, di-commit ke repo |

SVG dekorasi **wajib** inline dan tidak boleh `<img>`, karena harus bisa diwarnai lewat
`currentColor`/CSS variable — hal yang tidak mungkin dilakukan pada SVG yang dimuat sebagai
gambar.

Efek sampingnya menguntungkan: halaman `render-*.html` yang dihasilkan berdiri sendiri
sepenuhnya, sehingga fallback "browser tidak ditemukan, buka HTML-nya manual" (§10) benar-benar
berfungsi — user cukup dobel-klik satu file.

Ukuran: 6 screenshot @±500KB → base64 ±4MB per halaman. Chrome menanganinya tanpa masalah.
Halaman `render-*.html` adalah artefak sementara; boleh dihapus setelah PNG jadi, tapi
default-nya dibiarkan supaya bisa dipakai untuk fallback manual dan debugging.

Alternatif yang ditolak:

- **Python + Pillow.** Hanya butuh `pillow`, tanpa browser. Ditolak karena layout harus
  ditulis sebagai koordinat manual; text-wrapping, gradient, rounded corner, dan shadow
  berlapis semuanya dikerjakan tangan. Iterasi desain jadi lambat dan hasilnya cenderung
  terlihat mekanis.
- **AI image-gen untuk background + komposit screenshot.** Ditolak untuk versi ini
  (lihat §3).

### 4.2 Tiga aturan portabilitas (mengikat)

1. **Tanpa package manager.** Tidak ada `npm install`, tidak ada `pip install`. Yang
   dibutuhkan hanya: kemampuan menulis file, menjalankan shell, dan keberadaan browser
   Chromium-based. Ini membuat skill berperilaku identik di semua agent target.
2. **Tanpa jaringan saat render.** Font di-bundle lokal, dekorasi SVG lokal, screenshot
   dibaca dari filesystem. Render berjalan offline penuh, cepat, dan hasilnya reprodusibel.
3. **Progressive disclosure.** `SKILL.md` dijaga di bawah ±200 baris dan hanya berisi alur
   kerja serta aturan keputusan. Detail anatomi layout ada di `references/layouts.md`,
   jalur adb ada di `references/capture-adb.md`; keduanya hanya dibaca agent ketika
   memang dibutuhkan.

---

## 5. Struktur file

```
project-cover-maker/
├── SKILL.md                    # alur kerja + aturan keputusan (≤200 baris)
├── assets/
│   ├── template.html           # satu file, semua layout, dibuka lewat file://
│   ├── cover.css               # design token, device frame, arketipe layout
│   ├── cover.js                # baca cover.json → susun DOM → ekstrak palet
│   ├── fonts/
│   │   ├── Outfit-Bold.woff2   # wordmark
│   │   ├── Outfit-SemiBold.woff2
│   │   ├── Inter-Regular.woff2 # tagline, badge
│   │   └── Inter-Medium.woff2
│   └── decor/
│       ├── brush-01.svg … brush-04.svg
│       ├── blob-01.svg … blob-03.svg
│       ├── dots.svg
│       └── grid.svg
├── scripts/
│   ├── render.sh               # macOS/Linux
│   └── render.ps1              # Windows
├── references/
│   ├── layouts.md              # anatomi tiap arketipe + kapan dipakai
│   └── capture-adb.md          # protokol capture lewat adb
└── tests/
    ├── test.html               # unit test logika cover.js
    ├── fixture/                # 3 screenshot dummy + cover.json
    └── run.sh / run.ps1
```

Semua font berlisensi OFL (Outfit, Inter), boleh di-bundle. Dipakai subset latin dalam
format woff2, total di bawah ±200KB.

Catatan: `assets/cover.css` sudah berisi font woff2 dalam bentuk data URI base64 (lihat
§4.1.1), sehingga ukurannya ±250KB. Folder `assets/fonts/` menyimpan woff2 aslinya sebagai
sumber, dipakai kalau suatu saat perlu di-generate ulang. Folder `assets/decor/` menyimpan
SVG aslinya sebagai sumber; yang benar-benar dipakai saat render adalah salinan inline di
dalam `cover.js`.

### 5.1 Tanggung jawab render script

Script render mengerjakan empat hal:

1. **Cari binary browser.** Cek berurutan `chrome`, `google-chrome`, `chromium`, `msedge`
   di PATH; lalu path standar per-OS (Windows: `C:\Program Files\Google\Chrome\...`,
   `C:\Program Files (x86)\Microsoft\Edge\...`; macOS: `/Applications/Google Chrome.app/...`;
   Linux: `/usr/bin/chromium-browser` dst).
2. **Bangun halaman self-contained.** Baca `cover.json`, ubah tiap path gambar
   (`screens[].src`, `project.logo`, `badges[].src`) menjadi data URI base64, lalu
   substitusi hasilnya ke placeholder `__COVER_DATA__` di `template.html` dan tulis
   `render-<layout>.html` ke `output.dir`.
   Base64 memakai `base64 -w0` (Linux) / `base64 -i` (macOS) / `[Convert]::ToBase64String(
   [IO.File]::ReadAllBytes($p))` (Windows) — semuanya tersedia bawaan, konsisten dengan §4.2.
3. **Jalankan headless screenshot** dengan flag di §4.1.
4. **Ulangi untuk tiap layout** dalam render set (§8.3), tulis PNG ke `output.dir`.

Script tidak boleh berisi logika layout, warna, atau validasi — tugasnya murni substitusi
mekanis dan pemanggilan browser. Semua penentuan visual ada di `cover.js` dan `cover.css`.

---

## 6. Alur kerja agent

Enam langkah. Langkah 2 dan 5 adalah alasan skill ini masuk akal sebagai skill dan bukan
sebagai CLI biasa: ada mata yang memilih bahan di depan, dan ada mata yang mengoreksi
hasil di belakang.

### Langkah 1 — Kumpulkan bahan

- Glob screenshot berurutan di: `screenshots/`, `docs/screenshots/`, `assets/screenshots/`,
  `docs/`, `example/`, lalu root. Ekstensi diterima: `.png .jpg .jpeg .webp`.
- Cari logo: `logo.*`, `ic_launcher*`, `app_icon*`, `icon.*`.
- Baca `README.md` untuk nama project dan deskripsi.
- Kalau ada, ambil nama app dari `pubspec.yaml`, `build.gradle`(`.kts`), atau `package.json`.
- Kalau screenshot yang ditemukan 0 → buka jalur adb (§9.2).

### Langkah 2 — Agent melihat screenshot

Agent membuka tiap kandidat dengan Read (multimodal), lalu memutuskan:

- Mana yang paling representatif (biasanya home/dashboard) → jadi `hero`.
- Mana yang paling kaya secara visual (peta, chart, foto, list bergambar) → prioritas tinggi.
- Buang: duplikat, splash screen kosong, dialog error, screen dengan keyboard terbuka,
  screen yang isinya cuma teks placeholder/lorem.

Ambil 3-5 (maksimum 6), urutkan dari yang paling kuat, tandai tepat satu sebagai `hero`.

Kalau kandidat yang layak ternyata hanya 1-2, **itu kondisi yang sah, bukan kegagalan**.
Lanjutkan dengan yang ada; `auto` akan jatuh ke layout `solo` (§8.2). Agent memberi tahu
user bahwa menambah screenshot akan membuka layout lain, tapi tetap menyerahkan hasil.
Jangan pernah menolak user hanya karena screenshot-nya sedikit.

### Langkah 3 — Tulis `cover.json`

Semua keputusan agent dituang ke satu file data (§7). Termasuk menulis tagline kalau
README tidak punya kalimat yang enak dipakai. Pola tagline yang dipakai ketiga contoh
acuan sama: **satu kalimat manfaat, 6-10 kata**, bukan daftar fitur.

### Langkah 4 — Render

Jalankan render script → 4 PNG (atau sesuai jumlah layout yang diminta).

### Langkah 5 — Agent memeriksa hasil render-nya sendiri

Agent membuka keempat PNG dengan Read dan mengecek daftar konkret:

- Nama project kepotong atau meluber keluar kolom?
- Tagline menabrak mockup atau keluar kanvas?
- Kontras teks terhadap background di posisinya cukup?
- Ada HP yang menutupi bagian penting HP lain?
- Logo tenggelam di background (misal logo putih di area terang)?
- Badge tumpang tindih dengan elemen lain?

Kalau ada yang gagal → perbaiki `cover.json` (potong tagline, ganti layout, kunci palet
lebih gelap, kurangi jumlah screen) → render ulang **hanya layout yang bermasalah**.

**Maksimum 2 putaran koreksi.** Setelah itu agent menyerahkan hasil terbaik apa adanya
sambil menyebutkan sisa masalahnya. Batas ini ada supaya agent tidak berputar-putar.

### Langkah 6 — Serahkan

Berikan path keempat file plus satu kalimat per file tentang kenapa layout itu cocok,
supaya user gampang memilih.

---

## 7. Kontrak data — `cover.json`

Satu file ini adalah batas tegas antara pekerjaan LLM dan pekerjaan renderer. Agent hanya
boleh menulis file ini; renderer hanya boleh membaca file ini. Semua yang butuh penilaian
ada di sisi kiri batas, semua yang deterministik ada di sisi kanan.

```json
{
  "project": {
    "name": "TripMate",
    "tagline": "Your Smart Travel Assistant for Seamless Exploration",
    "logo": "assets/logo.png"
  },
  "screens": [
    { "src": "screenshots/home.png",   "role": "hero" },
    { "src": "screenshots/chat.png",   "role": "support" },
    { "src": "screenshots/detail.png", "role": "support" }
  ],
  "badges": [
    { "src": "assets/kampus.png", "label": "Universitas Gunadarma" }
  ],
  "meta": "C241-PS064",
  "layout": "auto",
  "palette": { "mode": "auto" },
  "decor": "auto",
  "output": { "dir": "cover-output", "scale": 2 }
}
```

### 7.1 Field

| Field | Wajib | Nilai | Default |
|---|---|---|---|
| `project.name` | ya | string 1-16 karakter | — |
| `project.tagline` | ya | string ≤64 karakter | — |
| `project.logo` | tidak | path relatif ke file gambar | null |
| `screens` | ya | array 1-6 objek | — |
| `screens[].src` | ya | path relatif, file harus ada | — |
| `screens[].role` | ya | `"hero"` \| `"support"`, tepat satu `hero` | — |
| `badges` | tidak | array 0-4 objek `{src, label}` | `[]` |
| `meta` | tidak | string ≤12 karakter | null |
| `layout` | tidak | `auto`\|`split-right`\|`split-left`\|`centered`\|`scatter`\|`solo` | `auto` |
| `palette.mode` | tidak | `auto` \| `manual` | `auto` |
| `palette.base/accent/ink/surfaceA/surfaceB` | kalau `manual` | string warna CSS | — |
| `decor` | tidak | `auto`\|`brush`\|`blob`\|`dots`\|`grid`\|`none` | `auto` |
| `output.dir` | tidak | path direktori | `cover-output` |
| `output.scale` | tidak | 1 \| 2 | 2 |

Semua field yang menerima `"auto"` **default-nya `auto`**. Artinya agent yang tidak yakin
tetap mendapat hasil bagus, sementara agent yang sudah melihat screenshot bisa mengambil
alih. Ini juga yang membuat iterasi di langkah 5 murah: perbaiki satu field, render ulang.

### 7.2 Aturan validasi

Divalidasi `cover.js` sebelum render, supaya kegagalan cepat dan pesannya spesifik.

| Aturan | Kalau dilanggar |
|---|---|
| `name` >16 karakter | Diterima, wordmark auto-shrink, tulis warning ke output |
| `tagline` >64 karakter | **Ditolak.** Dua baris adalah batas keras layout |
| `screens` kosong atau >6 | **Ditolak**, sebutkan jumlah yang ditemukan |
| `role: "hero"` bukan tepat satu | **Ditolak**, sebutkan berapa yang ada |
| `screens[].src` tidak ada/tidak terbaca | **Ditolak**, sebutkan file mana |
| `badges` >4 item | Item ke-5 dan seterusnya diabaikan, tulis warning |
| `meta` >12 karakter | Dipotong, tulis warning |
| `palette.mode: "manual"` tanpa warna lengkap | **Ditolak**, sebutkan field yang kurang |

Warning tidak menghentikan render. Penolakan menghentikan render dan menulis pesan yang
bisa langsung dipahami agent.

---

## 8. Sistem desain

### 8.1 Kanvas

1600×900 logis, dirender pada `output.scale` (default 2) sehingga hasil akhirnya 3200×1800.
**Semua ukuran memakai unit relatif terhadap lebar kanvas** (`vw` pada container ber-aspect
lock, atau `em` terhadap font-size root yang di-set dari lebar kanvas). Konsekuensinya:
mengganti scale tidak pernah menggeser layout.

### 8.2 Lima arketipe layout

- **`split-right`** — 3 HP overlap menumpuk di kiri membentuk fan; HP `hero` di posisi
  paling belakang dan paling tinggi. Wordmark + tagline + badge rata kiri di kolom kanan.
  Ini pola cover3 (TripMate). Default paling aman.
- **`split-left`** — cermin dari `split-right`. Dipakai kalau nama project panjang, karena
  mata membaca teks lebih dulu.
- **`centered`** — logo, wordmark, dan tagline ditumpuk rata tengah di sepertiga atas;
  3 HP berjajar simetris di bawah, bleed keluar batas bawah kanvas. Ini pola cover1
  (Jamali). Butuh logo mark yang layak.
- **`scatter`** — 5-6 HP dimiringkan (rotate −8° s/d +6°) tersebar mengisi ±60% area kiri;
  dua di antaranya sengaja bleed keluar batas kiri/atas. Teks di kanan. Ini pola cover2
  (Glowfy). Butuh minimal 5 screenshot.
- **`solo`** — satu HP besar dimiringkan tipis di kanan, teks berukuran besar di kiri.
  Untuk user yang hanya punya 1-2 screenshot.

### 8.3 Aturan pemilihan `auto` dan penentuan render set

**Syarat kelayakan tiap arketipe** (berdasar jumlah screen):

| Arketipe | Syarat |
|---|---|
| `solo` | `screens >= 1` |
| `split-right` | `screens >= 2` |
| `split-left` | `screens >= 2` |
| `centered` | `screens >= 3` |
| `scatter` | `screens >= 5` |

**Pilihan `auto`** — deterministik, dievaluasi berurutan, yang pertama cocok menang:

1. `screens.length < 3` → **`solo`**
2. `screens.length >= 5` → **`scatter`**
3. ada `project.logo` **dan** `name.length <= 10` → **`centered`**
4. `name.length > 10` **atau** `tagline.length > 45` → **`split-left`**
5. selain itu → **`split-right`**

**Render set** — yang benar-benar dirender adalah **maksimum 4 arketipe**, disusun begini:

1. Hasil pilihan `auto` di atas selalu masuk dan selalu jadi urutan pertama.
2. Isi sisanya dari arketipe yang **layak** menurut tabel di atas, mengikuti urutan
   prioritas `split-right → split-left → centered → scatter → solo`, lewati yang sudah
   terpilih, berhenti setelah total mencapai 4.
3. Kalau arketipe yang layak kurang dari 4, render semua yang layak saja.

Contoh: 2 screenshot → yang layak cuma `solo`, `split-right`, `split-left`; `auto` memilih
`solo`; render set jadi 3 file (`solo`, `split-right`, `split-left`). Dengan 6 screenshot,
kelimanya layak dan render set berisi 4 dari 5.

Kalau `layout` diisi eksplisit (bukan `"auto"`), yang dirender **hanya layout itu saja**,
satu file. Ini yang membuat iterasi di langkah 5 murah.

Karena beberapa layout tetap dirender bersamaan, aturan pemilihan `auto` sebenarnya hanya
menentukan **urutan penyajian** ke user, bukan pilihan final. Risikonya rendah kalau ada
kasus yang meleset.

### 8.4 Device frame (murni CSS)

- Rasio dikunci 9:19.5 (proporsi phone modern).
- Radius sudut 3.8% dari lebar HP.
- Bezel gelap setebal 1.1% dari lebar HP.
- Notch berupa pill dari pseudo-element di tengah atas.
- Shadow berlapis dua: satu *ambient* (lebar, tipis, offset kecil) dan satu *contact*
  (sempit, lebih pekat, offset ke bawah). Ini yang membuat HP terlihat duduk di kanvas
  dan bukan seperti stiker yang ditempel.
- Screenshot masuk dengan `object-fit: cover; object-position: top`. Screenshot dengan
  rasio berbeda dipotong dari bawah, tidak pernah digepengkan.

### 8.5 Ekstraksi palet

Dilakukan di dalam halaman itu sendiri oleh `cover.js`, sehingga tidak butuh library
color-extraction apapun.

**Langkah:**

1. Gambar screenshot `hero` ke `<canvas>` berukuran 100×200 (downscale sekaligus berfungsi
   sebagai averaging yang murah).
2. Baca pixel, **buang** yang:
   - hampir putih (lightness >92%),
   - hampir hitam (lightness <8%),
   - pucat (saturation <18%).

   Yang terbuang adalah chrome UI — background putih, teks hitam, garis abu. Yang tersisa
   adalah warna brand.
3. Sisa pixel dibucket ke 24 bin hue (@15°), tiap pixel dibobot oleh saturasinya. Bin dengan
   bobot terbesar → hue brand **H**.
4. Kalau total bobot sisa <2% dari jumlah pixel (app grayscale), pakai fallback **H = 215°**
   dan tulis warning supaya agent tahu dan bisa override manual.

**Penurunan palet — memakai OKLCH, bukan HSL.**

Ini keputusan yang perlu dicatat alasannya. Lightness pada HSL **tidak perseptual**:
`hsl(60 45% 32%)` (kuning) jauh lebih terang daripada `hsl(240 45% 32%)` (biru) meski angka
L-nya sama. Kalau palet diturunkan dari HSL, jaminan kontras akan bocor di hue kuning dan
cyan. Lightness pada OKLCH perseptual seragam, sehingga jaminannya benar-benar berlaku di
seluruh lingkaran hue. Chrome mendukung `oklch()` sejak versi 111, dan karena renderer-nya
memang Chrome, ini aman dipakai.

```
--base      = oklch(0.38 0.09 H)   /* wordmark, teks utama */
--accent    = oklch(0.55 0.13 H)   /* dekorasi, garis, aksen */
--ink       = oklch(0.30 0.05 H)   /* tagline */
--surface-a = oklch(0.97 0.02 H)   /* gradient stop terang */
--surface-b = oklch(0.86 0.06 H)   /* gradient stop gelap */
```

**Kenapa diturunkan dan bukan disampel:** kontras jadi tidak mungkin gagal. Teks selalu
berada di lightness 0.30-0.38, background selalu 0.86-0.97. Kalau warna disampel langsung
dari screenshot, cepat atau lambat akan ada app kuning terang yang membuat teksnya tidak
terbaca. Pendekatan ini menutup seluruh kelas bug tersebut di level desain, bukan di level
pengecekan.

Angka chroma di atas bisa keluar gamut sRGB di sebagian hue; browser akan meng-clamp dan
itu dapat diterima (clamp hanya mengurangi saturasi, tidak mengubah lightness). **Konstanta
lightness di atas divalidasi dan bila perlu disetel oleh Test #1 (§11); test itulah sumber
kebenarannya**, bukan angka yang tertulis di dokumen ini.

### 8.6 Lapisan dekorasi

Satu SVG di belakang mockup, diwarnai dengan `--accent`.

| Nilai | Bentuk | Referensi |
|---|---|---|
| `brush` | sapuan organik miring | cover3 (TripMate) |
| `blob` | lingkaran besar bleed dari bawah | cover3, layer kedua |
| `dots` | grid titik di sudut | cover1 (Jamali) |
| `grid` | garis tipis | — |
| `none` | tanpa dekorasi | — |

`auto` memilih berdasarkan arketipe: `split-*` → `brush`, `centered` → `dots`,
`scatter` → `blob`, `solo` → `blob`.

Ini satu-satunya bagian yang berupa aset file dan bukan CSS, karena bentuk organik memang
tidak bisa dibuat dengan CSS.

### 8.7 Tipografi

- **Outfit Bold** untuk wordmark (geometris, karakternya dekat dengan Gilroy yang dipakai
  contoh acuan). Di-embed sebagai data URI di `cover.css`, lihat §4.1.1 — memuat font dari
  `file://` tidak reliabel di Chrome.
- **Inter Regular/Medium** untuk tagline, badge label, dan `meta`.
- Ukuran wordmark **tidak fix**: `cover.js` mengukur lebar teks lalu men-fit ke lebar kolom,
  dibatasi maksimum 150px (pada skala 1x). Dengan begitu "TripMate" dan "Jamali Parenting"
  sama-sama mengisi penuh tanpa terpotong.
- Tagline: 34px/1.35, maksimum 2 baris.

---

## 9. Sumber input

### 9.1 Jalur folder (utama)

Selalu tersedia, tidak butuh apapun selain filesystem. Glob seperti di §6 langkah 1.
Kalau ditemukan lebih dari 6, agent yang menyaring lewat langkah 2.

### 9.2 Jalur adb (opsional)

Dibuka hanya kalau jalur folder tidak menemukan screenshot, atau user memintanya.

**Agent tidak menavigasi app sendiri.** Meng-drive UI app asing lewat `uiautomator dump`
sangat rapuh: agent tidak tahu nama screen-nya, tidak tahu apakah butuh login, dan tidak
tahu tombol mana yang destruktif. Pembagian kerjanya:

```
agent : "adb mendeteksi 1 device. Buka screen yang mau di-capture, lalu bilang 'oke'."
user  : "oke"
agent : adb exec-out screencap -p > screenshots/01.png  →  "tercapture. Next?"
```

User yang menavigasi, agent yang menangkap dan menamai. Tidak ada tebak-tebakan dan tidak
ada risiko agent menekan tombol destruktif di app orang.

**Demo mode status bar.** Sebelum sesi capture dimulai, nyalakan demo mode supaya status
bar bersih:

```
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command clock   -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
```

Jam 09:41, baterai penuh, sinyal penuh, tanpa notifikasi. Setelah sesi selesai, matikan
dengan `-e command exit`. Ini detail kecil yang membedakan cover yang terlihat seperti
materi portfolio dari cover yang terlihat seperti screenshot iseng — perhatikan status bar
di cover3 acuan: baterai 42% sedang mengisi, jam 14.54.

Protokol lengkapnya ditulis di `references/capture-adb.md` dan hanya dibaca agent ketika
jalur ini benar-benar dipakai.

---

## 10. Mode kegagalan

| Kejadian | Penanganan |
|---|---|
| Browser tidak ditemukan | Langkah 2 render script (§5.1) tetap dijalankan, sehingga `render-<layout>.html` yang self-contained tetap ditulis. Agent memberi path-nya: "buka file ini di browser, screenshot manual". Karena halamannya tidak punya resource eksternal (§4.1.1), file itu bisa dibuka di mesin manapun dan tampil identik. Skill tidak pernah pulang dengan tangan kosong. |
| Screenshot ditemukan 0 | Tawarkan jalur adb; kalau tidak ada device, minta user menunjukkan foldernya |
| Screenshot landscape/tablet | Warning + crop dari atas. Agent melihat hasilnya di langkah 5 dan bisa memutuskan membuang screenshot itu |
| Screenshot lebar <400px | Warning "akan buram pada scale 2", tetap dirender |
| Logo PNG berlatar putih | Terdeteksi lewat pengecekan pixel keempat sudut; diberi container rounded putih supaya tidak jadi kotak kaku di atas gradient |
| App grayscale, tidak ada hue dominan | Fallback hue 215°, tulis warning supaya agent bisa override manual |
| Render melewati budget waktu | `--virtual-time-budget=8000`; kalau lewat, PNG parsial tetap ditulis dan ditandai di output |

---

## 11. Testing

Tetap tanpa dependency, memakai Chrome yang sama dengan renderer.

**Test #1 — Invarian kontras (paling penting).**
Loop H dari 0 sampai 359. Untuk tiap H, turunkan palet sesuai §8.5, konversi ke sRGB, hitung
rasio kontras WCAG untuk dua pasangan terburuk: `--ink` di atas `--surface-b`, dan `--base`
di atas `--surface-b`. Assert keduanya ≥4.5:1 untuk seluruh 360 nilai.

Test inilah yang mengunci klaim di §8.5 bahwa kontras tidak mungkin gagal. Kalau suatu saat
ada yang mengubah angka lightness, test ini yang berteriak. Konstanta di §8.5 adalah nilai
awal yang diusulkan; kalau test menemukan hue yang gagal, konstantanya yang disesuaikan.

**Test #2 — Ekstraksi palet.**
Gambar sintetis dengan hue yang sudah diketahui (mis. 60% pixel putih + 25% pixel
`oklch(0.55 0.13 160)` + 15% teks hitam) → assert hue hasil ekstraksi dalam ±15° dari 160.
Plus kasus grayscale penuh → assert fallback 215° dan warning-nya terbit.

**Test #3 — Validasi kontrak.**
Setiap baris di tabel §7.2 menjadi satu test: input yang melanggar → assert ditolak/warning
sesuai kolom penanganan, dan assert pesannya menyebut field yang bermasalah.

**Test #4 — Pemilihan layout dan render set.**
Untuk `screens.length` 1 sampai 6, assert pilihan `auto` dan isi render set persis sesuai
§8.3. Minimal mencakup: 1 screen → set berisi 2 (`solo`, `split-right`); 2 screen → set
berisi 3; 3 screen → set berisi 4 tanpa `scatter`; 6 screen → set berisi 4 dengan `scatter`
di urutan pertama. Plus: `layout` eksplisit → set berisi tepat 1.

**Test #5 — Halaman render benar-benar self-contained.**
Bangun `render-*.html` dari fixture, lalu assert isinya **tidak mengandung** substring
`file://`, `http://`, `https://`, dan tidak ada atribut `src=`/`href=` yang bukan `data:`.
Test ini yang menjaga §4.1.1 — kalau suatu saat ada yang menambahkan referensi file
eksternal, ekstraksi palet akan mati diam-diam karena canvas tainting, dan test inilah yang
menangkapnya lebih dulu.

**Test #6 — Fixture render (end-to-end).**
`tests/fixture/` berisi 3 screenshot dummy + `cover.json`. Jalankan render penuh, lalu assert:
jumlah PNG sesuai render set (4 untuk fixture ini), tiap file >80KB (PNG putih polos ukurannya
jauh lebih kecil, jadi ambang ini menangkap render yang gagal diam-diam), dan dimensinya tepat
3200×1800.

Test #1-#4 adalah logika murni di `cover.js`, dijalankan lewat `tests/test.html` yang menulis
baris `PASS`/`FAIL` ke DOM, lalu `chrome --headless --dump-dom | grep FAIL`. Test #5 dan #6
membutuhkan render script. Semuanya nol dependency, konsisten dengan aturan §4.2.

**Yang sengaja tidak ditest: perbandingan pixel-per-pixel hasil render.** Rendering font
berbeda antara Windows, macOS, dan Linux, sehingga test semacam itu akan merah terus di mesin
orang lain padahal tidak ada yang rusak. Penjaga kualitas visualnya adalah langkah 5 pada alur
agent — agent yang melihat hasilnya sendiri.

---

## 12. Ringkasan invarian yang mengikat implementasi

1. Renderer tidak boleh berisi penilaian. Semua keputusan ada di `cover.json`.
2. Render script hanya melakukan substitusi mekanis dan pemanggilan browser — tidak berisi
   logika layout, warna, atau validasi.
3. Tidak ada dependency yang butuh dipasang; tidak ada akses jaringan saat render.
4. **Halaman render tidak boleh punya satu pun resource eksternal.** Semua gambar, font, dan
   SVG masuk sebagai data URI atau markup inline. Dikunci oleh Test #5.
5. Palet **diturunkan** dari satu angka hue, tidak pernah disampel langsung.
6. Kontras dijamin oleh konstruksi dan dikunci oleh Test #1.
7. Skill tidak boleh pulang dengan tangan kosong: kalau browser tidak ada, HTML self-contained
   tetap diserahkan.
8. Screenshot sedikit (1-2) adalah kondisi sah, bukan alasan menolak user.
9. Koreksi di langkah 5 maksimum 2 putaran.
10. `SKILL.md` ≤200 baris; detail masuk `references/`.

---

## 13. Perluasan yang disiapkan (bukan bagian versi ini)

- **Frame web/laptop** untuk project non-mobile. Arketipe layout dan sistem palet bisa
  dipakai ulang apa adanya; yang perlu ditambah hanya komponen frame dan satu-dua arketipe.
- **Background hasil AI image-gen.** Lapisan background sudah berupa layer terpisah, jadi
  bisa ditukar menjadi `<img>` PNG tanpa mengubah lapisan mockup, teks, maupun palet.
- **Rasio kanvas lain** (1:1 untuk Instagram, 1280×640 untuk GitHub social preview). Karena
  semua ukuran relatif terhadap lebar kanvas, yang perlu ditambah adalah aturan reflow per
  arketipe, bukan sistem baru.

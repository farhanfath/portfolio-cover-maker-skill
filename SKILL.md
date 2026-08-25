---
name: project-cover-maker
description: Use when the user wants a portfolio cover image for a mobile app project - builds four 3200x1800 cover variants from the app's real screenshots, with a colour palette derived from the app itself
---

# Project Cover Maker

Membuat cover portfolio untuk project **mobile app**: PNG 3200×1800 berisi mockup HP
dengan screenshot asli, nama project, tagline, dan palet warna yang diturunkan dari
screenshot itu sendiri.

Renderer-nya deterministik dan sengaja bodoh. Kualitas hasilnya ditentukan oleh dua
langkah yang hanya bisa kamu kerjakan: **memilih screenshot** (langkah 2) dan
**memeriksa hasil render** (langkah 5). Jangan lewati keduanya.

## Prasyarat

Chrome / Chromium / Edge terpasang. Tidak ada dependency lain. Kalau tidak ada browser
sama sekali, skill tetap menghasilkan halaman HTML self-contained yang bisa dibuka dan
di-screenshot user secara manual — jangan pernah pulang dengan tangan kosong.

## Dua akar path

Skill ini selalu bekerja di dua folder sekaligus. Jangan tertukar.

- **Skill root** — folder tempat `SKILL.md` ini berada; isinya `assets/`, `scripts/`,
  `references/`, `example/`. Perlakukan sebagai read-only. Kalau skill dipasang sebagai
  plugin, path-nya tersedia di environment variable `${CLAUDE_PLUGIN_ROOT}`.
- **Project user** — folder project yang sedang dikerjakan (cwd). Di sinilah screenshot
  dicari, `cover.json` ditulis, dan hasil render disimpan.

Di dokumen ini, path yang diawali `<skill>/` relatif terhadap skill root; path lain
relatif terhadap project user. **Jangan pernah menulis apa pun ke skill root** — satu
skill yang sama dipakai lintas project.

## Alur kerja

### 1. Kumpulkan bahan

Cari screenshot berurutan di dalam project user: `screenshots/`, `docs/screenshots/`,
`assets/screenshots/`, `docs/`, `example/`, lalu root. Ekstensi: `.png .jpg .jpeg .webp`.

Cari logo: `logo.*`, `ic_launcher*`, `app_icon*`, `icon.*`.
Baca `README.md` untuk nama project dan deskripsi. Kalau ada, ambil nama app dari
`pubspec.yaml`, `build.gradle(.kts)`, atau `package.json`.

Kalau screenshot yang ditemukan **nol**, baca `<skill>/references/capture-adb.md` dan
tawarkan jalur capture lewat adb.

### 2. Lihat screenshotnya

Buka tiap kandidat dengan Read. Putuskan:

- Yang paling representatif (biasanya home/dashboard) → jadi `hero`.
- Yang paling kaya secara visual (peta, chart, foto, list bergambar) → prioritas tinggi.
- Buang: duplikat, splash kosong, dialog error, screen dengan keyboard terbuka, screen
  berisi placeholder/lorem.

Ambil 3-5 (maksimum 6), urutkan dari yang paling kuat, tandai tepat satu sebagai `hero`.

**Kalau yang layak hanya 1-2, itu sah.** Lanjutkan; `solo` (1 screenshot) dan `duo`
(2 screenshot) memang untuk itu. Beri tahu user bahwa menambah screenshot membuka
layout lain, tapi tetap serahkan hasil. Jangan pernah menolak user karena
screenshot-nya sedikit.

### 3. Tulis `cover.json`

Taruh di folder yang sama dengan screenshot, di dalam project user. `src` relatif
terhadap file ini.

```json
{
  "project": { "name": "TripMate", "tagline": "Your smart travel assistant", "logo": null },
  "screens": [
    { "src": "home.png",   "role": "hero" },
    { "src": "chat.png",   "role": "support" },
    { "src": "detail.png", "role": "support" }
  ],
  "badges": [],
  "meta": null,
  "layout": "auto",
  "palette": { "mode": "auto" },
  "decor": "auto",
  "output": { "dir": "cover-output", "scale": 2 }
}
```

Batas keras (validator menolak file kalau dilanggar): `screens` harus 1-6 item dengan
tepat satu `hero`; `tagline` maksimum 64 karakter.

Batas lunak (validator tetap jalan, cuma memangkas dan mewarning): `name` >16 karakter
membuat wordmark mengecil otomatis tapi tetap dirender; `badges` >4 dipotong ke 4
pertama; `meta` >12 karakter dipotong ke 12. Kalau warning-nya muncul dan hasilnya
kurang bagus, perbaiki di langkah 5 — bukan berarti file ditolak.

**Tagline:** satu kalimat manfaat, 6-10 kata. Bukan daftar fitur. Tulis sendiri kalau
README tidak punya kalimat yang enak dipakai.

**`output.dir`** relatif terhadap `cover.json`, bukan terhadap cwd. Kalau screenshot
ada di folder dalam (mis. `docs/screenshots/`), set nilainya ke path yang wajar buat
user — mis. `"../../cover-output"` supaya hasil mendarat di root project.

Biarkan `layout`, `palette.mode`, dan `decor` di `"auto"` kecuali kamu punya alasan.
Nilai eksplisit `layout` yang valid: `solo`, `duo`, `split-right`, `split-left`,
`centered`, `diagonal`, `scatter` — anatominya di `<skill>/references/layouts.md`.

### 4. Render

```bash
# macOS/Linux
bash "${CLAUDE_PLUGIN_ROOT}/scripts/render.sh" path/to/cover.json

# Windows
powershell -File "${CLAUDE_PLUGIN_ROOT}\scripts\render.ps1" path/to/cover.json
```

Kalau `CLAUDE_PLUGIN_ROOT` kosong (skill dipasang manual, bukan lewat plugin), ganti
dengan path absolut skill root. Jangan pakai path relatif: cwd kamu adalah project
user, bukan skill root.

Menghasilkan hingga 4 PNG plus `render-*.html` di `output.dir`.

### 5. Periksa hasilnya

**Buka setiap PNG dengan Read.** Periksa:

- Nama project terpotong atau meluber keluar kolom?
- Tagline menabrak mockup atau keluar kanvas?
- Kontras teks terhadap background di posisinya cukup?
- Ada HP yang menutupi bagian penting HP lain?
- Logo tenggelam di background?
- Badge tumpang tindih?

Kalau ada yang gagal: perbaiki `cover.json` (potong tagline, kunci `layout`, kurangi
screen, atau set `palette.mode: "manual"`), lalu render ulang. Mengunci `layout` ke satu
nilai membuat render hanya menghasilkan satu file — itu cara termurah beriterasi.

**Maksimum 2 putaran koreksi.** Setelah itu serahkan hasil terbaik apa adanya sambil
menyebutkan sisa masalahnya.

### 6. Serahkan

Berikan path tiap file plus satu kalimat kenapa layout itu cocok, supaya user gampang
memilih.

## Referensi

- `<skill>/references/layouts.md` — anatomi ketujuh arketipe (`solo`, `duo`,
  `split-right`, `split-left`, `centered`, `diagonal`, `scatter`), kapan masing-masing
  dipakai. Baca kalau perlu memilih layout secara manual.
- `<skill>/example/cover1-5.webp` — cover acuan yang jadi dasar arketipe-arketipe itu.
  Buka dengan Read kalau user minta "yang modelnya kayak gini" atau kamu perlu
  membandingkan hasil render dengan target rasa yang dituju.
- `<skill>/references/capture-adb.md` — protokol capture lewat adb. Baca hanya kalau
  jalur itu dipakai.

## Yang tidak dikerjakan skill ini

Project non-mobile (web, dashboard, CLI, ML, backend). Frame device hanya phone.

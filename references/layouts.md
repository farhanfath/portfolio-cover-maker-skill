# Anatomi arketipe layout

Kanvas logis 1600×900, dirender 2× menjadi 3200×1800. Semua arketipe memakai DOM yang
sama: `.canvas.layout-<nama>` berisi `.decor`, `.stage` (satu `.phone` per screen, hero
lebih dulu), dan `.copy` (logo, nama, garis aksen, tagline, badge, meta).

## Syarat kelayakan

| Arketipe | Minimum screen |
|---|---|
| `solo` | 1 |
| `split-right` | 2 |
| `split-left` | 2 |
| `centered` | 3 |
| `scatter` | 5 |

## Pemilihan `auto`

Dievaluasi berurutan, yang pertama cocok menang:

1. `screens < 3` → `solo`
2. `screens >= 5` → `scatter`
3. ada logo **dan** nama ≤10 karakter → `centered`
4. nama >10 karakter **atau** tagline >45 karakter → `split-left`
5. selain itu → `split-right`

## Render set

Hasil `auto` selalu masuk dan selalu pertama. Sisanya diisi dari arketipe yang layak
mengikuti urutan `split-right → split-left → centered → scatter → solo`, berhenti di 4.
Kalau `layout` diisi eksplisit, hanya layout itu yang dirender — satu file.

## Tiap arketipe

### `solo`
Satu HP besar (`--pw: 380px`) dimiringkan −5° di kanan kanvas, teks besar di kolom kiri.
Untuk 1-2 screenshot — ini yang dipilih `auto` di bawah ambang 3.

### `split-right`
Tiga HP menumpuk membentuk fan di kiri: hero (`--pw: 340px`) paling belakang (z-index
terendah) dan paling tinggi di kanvas; dua pendukung (`--pw: 292px`) di depannya, lebih
rendah. Teks rata kiri di kolom kanan. Default paling aman untuk 3 screenshot dengan nama
pendek.

### `split-left`
Cermin geometris dari `split-right` (mockup kanan, teks kiri, dekorasi di-flip
horizontal). Dipakai kalau nama panjang atau tagline panjang, karena mata membaca teks
lebih dulu.

### `centered`
Logo, nama, garis, tagline ditumpuk rata tengah dekat puncak kanvas (`top: 72px`). Tiga
HP (satu `--pw: 300px` di tengah, dua `--pw: 268px` simetris di kaki) berjajar di bawah
dan bleed keluar batas bawah kanvas. Butuh logo mark yang layak; tanpa logo, bagian
atasnya terasa kosong.

### `scatter`
Sampai enam HP dimiringkan (−7° s/d +6°) tersebar di ±60% area kiri kanvas; hero
(`--pw: 300px`) selalu di depan (z-index tertinggi), pendukung lain lebih kecil
(`--pw: 190–230px`) dan sebagian bleed keluar tepi kiri/atas/bawah. Posisinya disusun
supaya kartu-kartu pendukung tidak saling menimpa penuh, dan satu-satunya tumpang tindih
yang tersisa (hero atas dua kartu belakang) berhenti sebelum menutupi pita header
(notch + judul layar) kartu di bawahnya. Teks di kanan. Paling ramai — pakai kalau
screenshot-nya memang bagus semua.

## Menyetel posisi

Semua posisi ada di `assets/cover.css` dalam blok `.layout-<nama>`. Ukuran HP diatur lewat
custom property `--pw` (lebar HP); tinggi, radius, bezel, notch, dan shadow semuanya
diturunkan dari `--pw`, jadi cukup ubah satu angka itu.

Tiap arketipe menyediakan lebih banyak slot `.phone` di CSS daripada jumlah minimum
kelayakannya (mis. `scatter` mengeset posisi untuk 6 slot walau kelayakan minimalnya 5),
supaya render tetap rapi kalau screen yang dikirim pas di jumlah maksimum yang wajar untuk
arketipe itu. Slot yang tidak kebagian posisi disembunyikan lewat idiom yang sama di semua
arketipe: `.layout-<nama> .stage .phone:nth-child(n+N) { display: none; }`, dengan `N`
adalah satu lebih dari jumlah slot yang diberi posisi (2 untuk `solo`, 4 untuk
`split-right`/`split-left`/`centered`, 7 untuk `scatter`). Kalau menambah slot posisi baru
untuk suatu arketipe, naikkan juga `N` pada aturan `nth-child` itu — kalau lupa, phone
tambahan akan menumpuk di posisi default (kiri-atas, tanpa transform) alih-alih
disembunyikan.

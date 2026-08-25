# Anatomi arketipe layout

Kanvas logis 1600×900, dirender 2× menjadi 3200×1800. Semua arketipe memakai DOM yang
sama: `.canvas.layout-<nama>` berisi `.decor`, `.stage` (satu `.phone` per screen, hero
lebih dulu), dan `.copy` (logo, nama, garis aksen, tagline, badge, meta).

## Syarat kelayakan

| Arketipe | Minimum screen | Slot posisi di CSS |
|---|---|---|
| `solo` | 1 | 1 |
| `duo` | 2 | 2 |
| `split-right` | 2 | 3 |
| `split-left` | 2 | 3 |
| `centered` | 3 | 3 |
| `diagonal` | 3 | 4 |
| `scatter` | 5 | 6 |

## Pemilihan `auto`

Dievaluasi berurutan, yang pertama cocok menang:

1. `screens == 1` → `solo`
2. `screens == 2` → `duo`
3. `screens >= 5` → `scatter`
4. ada logo **dan** nama ≤10 karakter → `centered`
5. nama >10 karakter **atau** tagline >45 karakter → `split-left`
6. selain itu → `split-right`

`diagonal` sengaja tidak punya cabang di sini. Ia arketipe pilihan, bukan default:
masuk ke render set lewat urutan prioritas di bawah, atau dipilih eksplisit lewat
`layout`.

## Render set

Hasil `auto` selalu masuk dan selalu pertama. Sisanya diisi dari arketipe yang layak
mengikuti urutan
`split-right → split-left → diagonal → centered → scatter → duo → solo`, berhenti di 4.
Kalau `layout` diisi eksplisit, hanya layout itu yang dirender — satu file.

## Tiap arketipe

### `solo`
Satu HP besar (`--pw: 380px`) dimiringkan −5° di kanan kanvas, teks besar di kolom kiri.
Pilihan `auto` kalau screenshot yang layak cuma satu. Tetap ada di render set untuk 2
screenshot, sebagai alternatif yang lebih tenang dari `duo`.

### `duo`
Dua HP tegak (depan `--pw: 320px`, belakang `--pw: 340px`) berdampingan di kanan,
tanpa rotasi sama sekali, keduanya bleed keluar batas bawah. Teks di kolom kiri.
Acuannya `example/cover5.webp`. Bedanya dengan `split-left`: HP-nya tidak dimiringkan
dan cuma dua, jadi kedua screenshot terbaca penuh — pakai ini kalau isi layarnya padat
(list berita, tabel, feed) dan sayang kalau dimiringkan. Tumpang tindihnya cuma 30px
dan berhenti jauh dari pita header HP belakang, jadi judul layar belakang tetap kebaca.

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

### `diagonal`
Sampai empat HP dimiringkan pada sudut yang sama (12°) dan disusun sebagai kisi
diagonal di paruh kanan: hero (`--pw: 330px`) utuh di tengah-kanan dan selalu paling
depan, dua kartu di atasnya (`--pw: 300px`) cuma kelihatan bagian bawahnya karena bleed
keluar batas atas, satu lagi cuma sepotong di tepi kanan. Teks di kolom kiri. Acuannya
`example/cover4.webp`. Bedanya dengan `scatter`: sudut rotasinya seragam dan posisinya
teratur, jadi kesannya rapi/teknis, bukan ramai. Cocok untuk app dengan satu layar
unggulan plus beberapa layar pendukung yang cukup dikenali dari potongannya saja.
Hanya empat slot yang diberi posisi — itu yang muat tanpa saling mengubur pada rotasi
sebesar ini, jadi screen ke-5 dan ke-6 disembunyikan.

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

Jumlah slot `.phone` yang diberi posisi per arketipe ada di tabel kelayakan di atas, dan
biasanya lebih banyak dari minimumnya (mis. `scatter` mengeset posisi untuk 6 slot walau
kelayakan minimalnya 5) supaya render tetap rapi kalau screen yang dikirim pas di jumlah
maksimum yang wajar untuk arketipe itu. Dua arketipe sengaja tidak begitu: `duo` memang
selalu dua HP, dan `diagonal` berhenti di empat karena rotasi 12° membuat slot kelima
pasti mengubur slot lain.

Slot yang tidak kebagian posisi disembunyikan lewat idiom yang sama di semua arketipe:
`.layout-<nama> .stage .phone:nth-child(n+N) { display: none; }`, dengan `N` adalah satu
lebih dari jumlah slot yang diberi posisi (2 untuk `solo`, 3 untuk `duo`, 4 untuk
`split-right`/`split-left`/`centered`, 5 untuk `diagonal`, 7 untuk `scatter`). Kalau
menambah slot posisi baru untuk suatu arketipe, naikkan juga `N` pada aturan
`nth-child` itu — kalau lupa, phone tambahan akan menumpuk di posisi default
(kiri-atas, tanpa transform) alih-alih disembunyikan.

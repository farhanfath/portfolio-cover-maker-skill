# Capture screenshot lewat adb

Dipakai hanya kalau jalur folder tidak menemukan screenshot, atau user memintanya.

## Aturan utama

**Jangan menavigasi app sendiri.** Ini bukan soal kesopanan, ini soal risiko nyata:

- Kamu tidak tahu nama screen-nya, jadi kamu tidak bisa menilai apakah "Login" yang
  muncul itu langkah wajar atau tanda kamu salah alur.
- Kamu tidak tahu apakah suatu aksi butuh state tertentu (akun login, data terisi,
  koneksi jaringan) — menavigasi buta bisa mendarat di error state yang justru jadi
  screenshot buruk untuk cover.
- Kamu tidak tahu tombol mana yang destruktif. "Hapus akun", "Reset", "Logout",
  "Kirim" — di app asing, teks tombol saja tidak cukup untuk menjamin aman ditekan.
- `uiautomator dump` (atau pendekatan sejenis untuk "membaca" UI lalu mengetuk
  koordinat) rapuh secara teknis juga: layout berubah antar versi app, animasi bikin
  koordinat meleset, dan kegagalan senyap (tap kena tempat lain) tidak selalu
  terlihat dari sisi kamu.

Karena alasannya bukan sekadar "aturannya begitu", jangan cari jalan pintar kalau ada
situasi yang terasa hampir aman ("cuma satu tap ke tab berikutnya", "tombol ini jelas
tidak berbahaya") — penilaian itu butuh konteks app yang cuma dimiliki user. Pembagian
kerjanya tetap: **user menavigasi, kamu menangkap.**

## 1. Cek device

```bash
adb devices
```

Kalau tidak ada device berstatus `device` (bukan `unauthorized`/`offline`), hentikan
jalur ini dan minta user menunjukkan folder screenshot-nya.

## 2. Nyalakan demo mode

Membuat status bar bersih: jam 09:41, baterai penuh, sinyal penuh, tanpa notifikasi.
Ini yang membedakan cover yang terlihat seperti materi portfolio dari screenshot iseng.

```bash
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command clock   -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
```

## 3. Sesi capture

Ulangi per screen. Tunggu konfirmasi user tiap kali — jangan pernah capture tanpa diminta.

```
kamu : "Buka screen yang mau di-capture, lalu bilang 'oke'."
user : "oke"
kamu : adb exec-out screencap -p > screenshots/01-home.png
kamu : "Tercapture sebagai 01-home.png. Next, atau sudah cukup?"
```

Beri nama file berurutan dan deskriptif (`01-home.png`, `02-detail.png`) supaya urutannya
jelas saat kamu memilih di langkah 2 alur utama.

Berhenti setelah 6 — lebih dari itu tidak terpakai.

## 4. Matikan demo mode

**Selalu jalankan ini setelah selesai**, jangan tinggalkan device user dalam demo mode.

```bash
adb shell am broadcast -a com.android.systemui.demo -e command exit
```

## 5. Lanjutkan alur utama

Kembali ke langkah 2 di `SKILL.md`: lihat hasil capture-nya, pilih dan urutkan.

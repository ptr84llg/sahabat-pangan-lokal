# Sahabat Pangan Lokal

Sahabat Pangan Lokal adalah game edukasi literasi pangan lokal berbasis Godot untuk PC/laptop, tablet, dan smartphone.

<!-- RELEASE_STATUS:START -->
## Release terbaru

**Sahabat Pangan Lokal v1.0.0** merupakan baseline **Final Production Release**.

- Status: Final Production Release
- Version Name: 1.0.0
- Version Code: 100
- Package ID: id.sahabatpanganlokal.game
- Target SDK: 36
- Godot Engine: 4.7.2
- Git Tag: [v1.0.0](https://github.com/ptr84llg/sahabat-pangan-lokal/releases/tag/v1.0.0)
- Source Release Commit: c2911a6b94cb5df3eb98f02f2300d43b73b54320

### Ringkasan v1.0.0

- Alur permainan Level 1 sampai Level 5 telah difinalisasi
- Sistem progress, history, achievement, gallery, settings, dan telemetry telah terintegrasi
- Sistem 14 gelar atau achievement telah diterapkan
- Tampilan Main Game Success telah distandardisasi
- Konfigurasi Android production release telah difinalisasi
- APK dan AAB production telah ditandatangani dan diverifikasi
- Penyesuaian scene final sebelum penguncian v1.0.0 telah dimasukkan ke source release

> APK dan AAB production tidak disimpan sebagai file repository Git. Identitas release, source tag, dan catatan perubahan dikelola melalui GitHub Release.
<!-- RELEASE_STATUS:END -->


## Baseline teknis

- Godot 4.7.2 stable
- Alur permainan Level 1 sampai Level 5
- Native save schema 3
- Progress, history, achievement, gallery, settings, dan telemetry menggunakan arsitektur native V3
- Konfigurasi runtime menggunakan authoritative config per domain
- Visual asset runtime diakses melalui VisualAssetConfig dan VisualAssets
- Motion UI menggunakan UIMotion dan ScreenMotionPresenter
- Repository utama: ptr84llg/sahabat-pangan-lokal

## Struktur utama

- `assets/` aset visual, audio, dan font
- `data/` konten permainan
- `resources/config/` authoritative resource configuration
- `scenes/` scene aplikasi, level, dan shared UI
- `scripts/autoload/` service dan state global
- `scripts/config/` schema resource configuration
- `scripts/shared/` komponen runtime yang dipakai lintas scene

## Menjalankan project

Buka `project.godot` dengan Godot 4.7.2 stable.

Pengujian release dilakukan melalui whole-project headless gate dan pengujian manual alur Level 1 sampai Level 5 sebelum APK/AAB production dibuat.

## Keamanan release

Keystore, private key, environment credential, file signing lokal, APK, dan AAB tidak boleh disimpan ke repository.

`export_presets.cfg` boleh disimpan setelah Android export configuration final karena file tersebut dibutuhkan untuk reproducible export, tetapi credential privat tetap harus berada di luar Git.
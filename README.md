# Sahabat Pangan Lokal â€” Godot Levels 1â€“5 Build v1.4

Build v1.4 melanjutkan Levels 1â€“4 v1.3 dengan implementasi **Level 5 â€” Festival Pangan Lokal**. Seluruh perjalanan Rumah â†’ Sekolah â†’ Pasar â†’ Dapur â†’ Festival kini tersedia dalam satu proyek Godot foundation/prototype.

## Level 5 yang diimplementasikan

- 14 pangan dari Level 1â€“3, tanpa pangan baru Level 5
- dua moving lane berlawanan arah dengan assignment 7 + 7 yang di-shuffle setiap entry/replay
- kartu yang benar ditahan sementara oleh MissionArea dan kembali ke `origin_lane` saat skema selesai
- satu Main Timer baseline 240 detik dari Skema 1 sampai Skema 4
- timer 00:00 **tidak** menghentikan permainan, hanya membuat bonus waktu 0
- Skema 1 Temukan Pangan: 3 target nama
- Skema 2 Penuhi Kelompok: Pangan Pokok dan Umbi, Sayuran, Buah, Hasil Perikanan
- Skema 3 Belanja Festival: tepat satu pangan dari setiap kelompok dan total â‰¤ 15 Koin
- Skema 4 Rakit Olahan: 2 target hasil olahan, dua bahan utama tanpa urutan, lalu proses sederhana
- scoring Main Game 50 poin ketepatan + maksimum 10 bonus waktu
- Literacy Challenge 5 soal Ã— 30 detik
- shuffle ganda: urutan soal dan posisi jawaban Aâ€“D
- kunci jawaban memakai `correct_answer_id`, bukan huruf posisi
- benar = 8, salah = 0, timeout = 0, tanpa retry
- galeri konsolidasi 14 pangan + 4 hasil olahan
- badge **Duta Pangan Lokal** tanpa syarat skor minimum
- Final Map prototype menampilkan skor dan active duration Level 1â€“5, total skor game /500, dan total durasi aktif
- Run berubah menjadi `COMPLETED` setelah Level 5 diselesaikan

## Status konten

Empat hasil olahan Level 4 tetap **PROVISIONAL**. Ikan Lele tetap **PROVISIONAL**. Enam nilai Koin yang tidak berasal dari Level 3 tetap **BALANCING DRAFT** pada master content. Lima teks quiz Level 5 di build ini merupakan **development content** yang mengikuti pola Q01â€“Q05 storyboard dan tetap wajib divalidasi ahli materi sebelum versi final.

## Pilihan implementasi Level 5

Storyboard mengunci tiga target pada Skema 1 tetapi tidak mengunci tiga nama final. Build memilih tiga target secara acak dari bank 14 pangan setiap entry. Storyboard juga mengunci dua hasil olahan pada Skema 4 tetapi tidak mengunci pasangan target final, sehingga build memilih dua dari empat hasil olahan secara acak. Kedua keputusan ditempatkan di JSON agar dapat diubah tanpa mengedit scene.

Moving lane memakai `FoodCard` yang sama dengan level sebelumnya. `MovingLaneController` menyimpan `origin_lane` per `food_id`, sehingga card yang dipakai MissionArea tidak dibuat ulang dan tidak berpindah lane antar-skema.

## Belum final

- visual assets pangan, karakter, background, badge, audio, dan FX final
- kecepatan moving lane setelah playtest siswa
- Main Timer final setelah playtest
- nilai Koin balancing draft
- validasi ahli materi Ikan Lele, empat hasil olahan, distractor, dan lima soal quiz
- cloud sync / backend publikasi

## Menjalankan

Buka `project.godot` pada Godot 4.6.1. Untuk development, progression normal membuka level secara berurutan. Setelah Level 5, Final Map prototype menampilkan recap perjalanan dan semua level tetap dapat replay.

## Validasi statis

```bash
python tools/validate_project.py
python tools/simulate_rules.py
```

Build lokal telah lolos validasi struktur dan aturan, Godot 4.6.1 headless import, serta headless boot tanpa fatal signal. Pengujian visual, interaksi mouse/touch, alur penuh, dan berbagai rasio layar tetap mengikuti `docs/MANUAL_TEST_CHECKLIST.md`.


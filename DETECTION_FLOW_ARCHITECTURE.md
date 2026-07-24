# Arsitektur & Alur Deteksi Biny (Single & Mixed Waste)

Dokumen ini menjelaskan alur sistem deteksi sampah (_Single_ maupun _Mixed_) pada aplikasi Biny saat ini, mencakup skenario ketika aplikasi berada dalam kondisi **Online** maupun **Offline**. Perubahan ini memastikan akurasi tinggi menggunakan AI (Gemini) saat online, dan _fallback_ model lokal yang tangguh saat offline, ditambah dengan mekanisme _cache_ (Local Dataset) yang diperbarui.

---

## 1. Single Waste Detection (`classifyImage`)

Alur ini dijalankan saat pengguna memindai satu objek sampah tunggal.

### Kondisi Online

1. **Parallel Background Task**: Segera setelah fungsi dipanggil, _request_ ke **Gemini AI** (_cloud_) mulai dijalankan di _background_. Hal ini mencegah terjadinya pemblokiran (blocking), sementara model lokal tetap memproses gambar secara paralel.
2. **Local Model Execution**: Sistem menjalankan model **RT-DETR** untuk menemukan letak objek di dalam _frame_ (mendapatkan _bounding box_) lalu memotong (_crop_) gambar agar fokus pada objek. Jika RT-DETR gagal/kosong, _fallback_ menggunakan **TFLite** dengan _center crop_ agar _background_ visual di sekitar objek terbuang.
3. **Approval System (Gemini sebagai Guru)**:
   Setelah deteksi lokal selesai, fungsi akan menunggu (await) hasil dari Gemini. Hasil deteksi lokal akan divalidasi oleh tebakan Gemini:
   - **Level 1**: Apakah Gemini menebak bahwa objek termasuk 5 kategori utama? (Tidak menebak "Lainnya").
   - **Level 2**: Apakah kategori tebakan Lokal sama persis dengan tebakan Gemini?
   - **Lolos**: Jika akurat, hasil lokal digunakan, langsung diarahkan ke halaman `/result`.
   - **Ditolak**: Jika Gemini menebak "Lainnya" (Level 1 gagal), langsung diarahkan ke halaman `/unknown-detected`.
   - **Ditolak**: Jika tidak sesuai (Level 2 gagal), hasil Gemini ditampilkan di bar atas dengan confidence (di-_random_ antara 51% - 70%). Dan hasil lokal yang tadi tidak akurat ditampilkan di bar bawah dengan confidence (di-_random_ antara 1% - 50%). Hal ini merupakan trik _psikologi UX_ dan untuk **memaksa sistem UI mengarahkan user ke halaman `/low-confidence`** (yang membutuhkan validasi/koreksi manual dari pengguna).

### Kondisi Offline (Tanpa Koneksi Internet / Layanan Gemini Gagal)

1. **Pengecekan Local Dataset (Cache)**: Sebelum menjalankan model ML (karena offline Gemini tidak menyala), sistem mencocokkan _perceptual hash_ (pHash) gambar dengan data historis di **Local Dataset** yang memiliki label source 'human' dan 'gemini'. Jika ada kemiripan visual gambar dengan sampah yang pernah dipindai sebelumnya, sistem langsung me-return hasil dari basis data (_bypass hasil deteksi model lokal_). _Perlu dicatat, \_label source_ 'model' diabaikan dalam proses ini, sehingga sistem tidak akan menggunakan hasil deteksi model lokal yang belum terverifikasi oleh user atau Gemini.\_
2. **Local Model Execution**: Menjalankan RT-DETR atau TFLite (sama seperti pada kondisi online).
3. **Validasi User Choice**: Sistem lalu mencocokkan deteksi model lokal dengan kategori awal yang dipilih pengguna (di halaman `/category-select`). Jika terjadi konflik (contoh: user memilih plastik, tapi model lokal mendeteksi logam). Bar atas menampilkan hasil model lokal dengan confidence (di-_random_ antara 51% - 70%). Bar bawah menampilkan pilihan dari user, kasih confidence yang rendah (di-_random_ antara 1% - 50%). Agar memaksa sistem terdorong masuk ke halaman `/low-confidence` untuk meminta konfirmasi ulang dari pengguna walaupun saat kondisi offline.

---

## 2. Mixed Waste Detection (`classifyMultipleImages`)

Alur ini dijalankan saat pengguna memindai banyak sampah yang menumpuk sekaligus.

### Kondisi Online

- **Full Gemini API**: Aplikasi **sepenuhnya melempar tugas klasifikasi ke Gemini** (`geminiService.classifyMultiple`). Model RT-DETR/TFLite lokal tidak dilibatkan sama sekali.
- Gemini akan mendeteksi seluruh benda di gambar dan mengembalikan sekumpulan _item_ lengkap dengan _normalized bounding box_.
- Biny kemudian memotong (_crop_) gambar asli untuk masing-masing item berdasarkan koordinat _bounding box_ dari Gemini.
- Setiap objek yang di-_crop_ tadi disimpan secara otomatis dan asinkron ke dalam _Local Dataset_.

### Kondisi Offline (Fallback)

- **RT-DETR + Local Dataset Enrichment**: Karena Gemini tak tersedia, aplikasi menjalankan **RT-DETR** (`detectObjects`) secara lokal untuk mengenali beberapa _bounding box_ sekaligus.
- Setiap _bounding box_ di-crop, dan potongan spesifik tersebut akan **dicocokkan (_enriched_) dengan data pada Local Dataset**.
- **TFLite Fallback**: Jika RT-DETR offline ini tidak mendeteksi bentuk apa-apa sama sekali, _fallback_ darurat dilakukan dengan memberikan keseluruhan foto (_full frame_) ke model **TFLite** biasa.
- Jika ada kemiripan gambar hasil deteksi model lokal (RT-DETR/TFLite) secara visual (via pHash) dengan sampah yang pernah disahkan oleh user sebelumnya di **Local Dataset**, _confidence_ item tersebut dimanipulasi menjadi sangat tinggi (90% - 99%) dan meminjam label kategori dari _database_ lokal tersebut. Hasil deteksi dari Gemini yang disimpan di **Local Dataset** tidak perlu dimanipulasi karena sudah pasti akurat.

---

## 3. Eskalasi / Deteksi Ulang AI (Re-analyze)

Ini merupakan mekanisme saat user menekan **"Analisis AI"** (pada halaman `/unknown-detected`) dan (pada halaman `/multi-result`) jika ada objek yang terdeteksi oleh Gemini sebagai "Lainnya", sehingga perlu dipencet tombol "Analisis AI" untuk memvalidasi ulang itu termasuk kategori apa (agar bisa ditampilkan logo, warna, dan nama kategori nya).

- **Selalu Online & Bypass Dataset**: Karena user secara eksplisit meminta analisis ulang atau opini kedua yang segar dari Cloud AI, request ini **selalu langsung dikirim ke Gemini** dan dengan sengaja melewati proses pengecekan ke _Local Dataset_.
- **Bounding Box Preservation**: Pada deteksi ulang di mode _mixed/multi_, aplikasi menggunakan potongan gambar (_cropped image_) dari item tertentu dan memastikan informasi gambar maupun dimensi _bounding box_ aslinya tetap dipertahankan di state. Ini mencegah tampilan UI _card_ individual yang rusak/berubah karena pergantian dimensi.

---

## 4. Local Dataset Service (Cache & ML Strict Supervised Learning)

Terdapat perombakan fundamental terkait cara menyimpan cache / sejarah scan (_Local Dataset Service_):

1. **Hashing ganda**: Sistem menyimpan gambar dengan kunci **SHA-256** (untuk deduplikasi file 100% sama) serta menambahkan nilai **pHash (Perceptual Hash)** untuk mengukur kemiripan dua gambar lewat jarak _Hamming_ (_Hamming Distance_).
2. **Strict Supervised Learning**: Saat fungsi `findMatch()` melakukan perbandingan gambar _offline_, kini ia **hanya** mempercayai data historis yang bersumber (`labelSource`) dari `'human'` (koreksi manual/pengguna) atau `'gemini'` (sudah disahkan Gemini AI). Label tebakan awal model lokal (`'model'`) **diabaikan/dibuang**. Ini merupakan _safety net_ untuk mencegah sistem belajar dari kesalahannya sendiri (_compounding errors_) sewaktu perangkat sering dipakai offline.
3. **Penyimpanan Tepat Guna**: File JPEG disimpan secara rahasia di folder _Application Support_ agar tidak mengotori Galeri / iCloud backup milik pengguna, dan **akan otomatis dihapus seketika** (garbage collected dari internal) jika sinkronisasinya ke _backend database_ Supabase sudah berhasil. Data di _local memory_ yang disisakan hanya meta-nya (pHash & kategori) di dalam Hive.

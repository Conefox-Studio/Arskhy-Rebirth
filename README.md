# Arskhy Rebirth

**Arskhy Rebirth** adalah game aksi-petualangan (*side-scrolling action-adventure RPG*) bergaya *2D pixel-art dark fantasy* yang dibangun menggunakan **Godot Engine** (GDScript). Proyek ini dikembangkan oleh **Rationatsu** di bawah naungan **Conefox Studio**.

---

## Latar Belakang & Alur Cerita

Kisah bermula di bawah langit malam bertabur bintang, ketika **Arskhy** dan **Skyumi** menyambut kelahiran anak mereka. Keduanya sepakat menamainya **Shyrnaru** gabungan dari nama mereka berdua yang terdengar kokoh dan maskulin. Namun, tiga tahun berselang, Arskhy menyadari bahwa suara tawa kecil sang anak tidak memiliki nada berat khas anak laki-laki, melainkan lembut dan jernih menyerupai suara Skyumi. Menyadari bahwa buah hati mereka adalah seorang perempuan, pada malam itu juga mereka mengganti namanya menjadi **Shyrn**.

Dua belas tahun berlalu sejak malam tersebut. Memasuki **Chapter 1: Autumn**, cerita berlatar di dataran terkutuk **Aethelgard**, sebuah dunia dengan langit kelabu kehitaman yang diselimuti kabut tebal dari reruntuhan menara kuno. Pemain berperan memandu Shyrn melintasi berbagai wilayah sunyi dan berbahaya.

---

## Fitur Utama

### 1. Mekanik Pergerakan & Eksplorasi
* **Kontrol Platforming Presisi**: Mendukung pergerakan halus dengan fitur *double jump*, *coyote time* (toleransi lompatan di tepi pijakan), *variable jump height* (tinggi lompatan menyesuaikan durasi tombol ditekan), *dash*, serta *sprint*.
* **Interaksi Lingkungan**: Pemain dapat mendorong objek berat (*pushable crates*), menghancurkan struktur kayu tertentu, dan menghindari jebakan lingkungan seperti barel menggelinding (*rolling barrels*) serta semak berduri yang memberikan efek *bleed* (pendarahan berkelanjutan).

### 2. Sistem Pertarungan, Sihir & Rage Mode
* **Pertarungan Jarak Dekat & Jauh**: Kombinasi serangan tebasan fisik (*melee*) dan sistem sihir berbasis *Magic Points* (MP).
* **Koleksi Mantra (*Spells*)**: Pemain dapat berganti-ganti mantra secara langsung selama pertempuran, meliputi serangan proyektil lurus maupun serangan area (*ground cast*), seperti *Fireball*, *Spark Bolt*, *Wind Slash*, *Sky Slash*, *Flame Pillar*, *Thorn Roots*, dan *Stone Spikes*.
* **Range / Rage Mode**: Mode khusus yang dapat diaktifkan untuk menggandakan daya rusak serangan pemain terhadap musuh biasa maupun bos.

### 3. Pertarungan Bos (Ghost Executor)
* **AI Multi-Fase**: Bos utama **Ghost Executor** memiliki pola serangan dinamis berupa tebasan sabit jarak dekat (*melee*), serangan duri tanah (*skill*), serta kemampuan memanggil pasukan hantu kecil (*summon*) sebagai musuh boss bawaan/untuk test saja.
* **Manajemen Energi Bos**: Selain memiliki *HP Bar* yang berskala sesuai tingkat kesulitan, bos juga menggunakan *Magic Bar* tersendiri yang terkuras setiap kali melancarkan serangan sihir atau memanggil anak buah, lalu pulih secara bertahap.

### 4. Siklus Waktu & Atmosfer Dinamis
* **Siklus Siang dan Malam (*Day/Night Cycle*)**: Waktu berjalan secara *real-time* antar-area dengan total durasi 18 menit untuk satu siklus penuh (3 menit Pagi, 4 menit Siang, 3 menit Sore, dan 8 menit Malam).
* **Perubahan Visual & Audio**: Pergantian waktu memengaruhi pencahayaan global (*CanvasModulate*), intensitas serta warna *god rays*, kemunculan partikel malam, hingga pergantian musik latar secara otomatis.
* **Sistem Cuaca & Lingkungan**: Dilengkapi efek kabut tebal, hembusan angin, dedaunan jatuh, dan satwa liar (seperti capung di area hutan) yang dapat disesuaikan melalui pengaturan grafis.

### 5. Sistem Perjalanan (*Journey*) & Tingkat Kesulitan
Setiap sesi *New Game* dihitung sebagai satu perjalanan (*journey*). Game menerapkan aturan **2 kali pingsan (*faint*) = mati permanen**, yang mengharuskan pemain mengulang perjalanan dari awal apabila kehabisan kesempatan. Tingkat kesulitan menentukan jumlah *HP* awal, jumlah musuh yang muncul, *HP* bos, serta kuota penyimpanan (*save slots*):
* **Easy**: 30 HP awal | Penyimpanan tak terbatas (menimpa slot 1).
* **Normal**: 20 HP awal | Maksimal 5 slot penyimpanan per perjalanan.
* **Hard**: 15 HP awal | Maksimal 3 slot penyimpanan per perjalanan.
* **Hardcore**: 10 HP awal | Hanya 1 slot penyimpanan per perjalanan.

### 6. Manajemen Inventory & Pencapaian (*Achievements*)
* **Sistem Tas Dua Kantong**: Terbagi menjadi kantong **Items** (kapasitas 8 slot, tumpukan maksimal 99) dan **Key Items** (kapasitas 5 slot untuk item penting seperti peta), dilengkapi 2 *hotbar* akses cepat.
* **Sistem Achievement Lokal**: Menyimpan progres pencapaian pemain secara otomatis, antara lain *First Steps*, *Heavy Lifter*, *Barrel Roll*, *Rage Unleashed*, *Ghost Hunter*, *Hardcore Survivor*, dan *Demo Complete*.

### 7. Deteksi Perangkat Input Lintas Platform
Sistem `DeviceMode` secara otomatis mengenali perangkat input terakhir yang digunakan pemain tanpa perlu pengaturan manual:
* **Keyboard & Mouse**: Menampilkan ikon tombol keyboard dengan dukungan kustomisasi tombol penuh (*keybind remapping*).
* **Controller / Gamepad**: Mendeteksi jenis kontroler secara otomatis (Xbox, PlayStation, atau Nintendo Switch) dan menyesuaikan ikon antarmuka.
* **Touchscreen / Mobile (Android & iOS)**: Menampilkan antarmuka tombol virtual D-Pad dan tombol aksi multi-sentuh (*multi-touch*) tanpa joystick analog, lengkap dengan editor tata letak (*Touch Layout Editor*) dan pengaturan transparansi.

---

## Struktur Area & Peta

1. **Prolog (Story Book & Chapter Intro)**: Pembuka narasi interaktif berbentuk buku cerita sebelum memasuki bab pertama.
2. **Map 0 (Aethelgard)**: Area pembuka dengan narasi bergaya *typewriter* dan atmosfer berkabut.
3. **Shynetown**: Area pemukiman awal dan titik transisi menuju wilayah hutan.
4. **Jungle & Jungle Routes (1 - 4)**: Wilayah hutan berlapis dengan jalur bercabang, musuh hantu, rintangan berduri, dan teka-teki lingkungan.
5. **Cave**: Area gua vertikal dengan tingkat pencahayaan sangat rendah (visibilitas 2%) yang mengandalkan cahaya di sekitar karakter serta jebakan bebatuan mematikan.
6. **( map lainya akan di update )**
7. **Boss Map**: Arena tertutup tempat pertarungan melawan Ghost Executor sebagai test berlangsung.
8. **Before Ending & Credits**: Area penutup menuju layar kredit akhir dan pembukaan mode kesulitan lanjutan.

---

## Kontrol Dasar (Keyboard)

| Aksi | Tombol Default |
| :--- | :--- |
| Bergerak Kiri / Kanan | `A` / `D` atau `Panah Kiri` / `Panah Kanan` |
| Lompat / Double Jump | `Space` / `W` / `Panah Atas` |
| Dash / Lari (Tahan) | `K` / `X` / `Shift` |
| Serangan Fisik (Melee) | `J` / `Z` |
| Gunakan Sihir (Cast Magic) | `E` |
| Ganti Mantra Sebelumnya / Berikutnya | `0` / `-` |
| Aktifkan Range / Rage Mode | `Q` |
| Buka / Tutup Inventory | `I` / `Tab` |
| Pilih Slot Cepat 1 / 2 | `1` / `2` |
| Gunakan Item Slot Cepat | `Y` |

---

## Info

Seluruh sistem antarmuka pengguna (UI), fisika karakter, hingga logika dunia dibangun secara modular menggunakan GDScript:
* Mengatur penyimpanan data perjalanan (*save/load*), jumlah *faint*, tingkat kesulitan, serta konfigurasi grafis dan audio.
* Kelas induk (*base class*) untuk seluruh peta *side-scroller*, menangani pemuatan peta JSON, *tile collision* presisi, latar paralaks, sistem bayangan dinamis, dan pemicu dialog.
* Mengelola mesin status (*state machine*) karakter Shyrn, fisika pergerakan, deteksi tumbukan serangan, dan perilaku proyektil sihir.
* Mengatur kecerdasan buatan musuh, sistem *aggro*, dan mekanik pertarungan bos.
* Mengontrol transisi waktu harian, pencahayaan malam, aurora, dan efek partikel cuaca.
* Mengatur peralihan input otomatis dan penyesuaian kontrol layar sentuh.

---

## Kredit & Kontributor

* **Creator, Story, Programming, Art & Music**: Rationatsu
* **Main Original Character**: shyrn
* **Animation**: Opium
* **Special Thanks**: Kouzerumatsukitsune, Foxy, Ary's, serta seluruh keluarga, sahabat, dan pendukung proyek ini.

---

## Tautan Resmi

> **Catatan**: Versi yang tersedia pada repositori/tautan demo merupakan versi uji coba. Untuk mendapatkan versi penuh secara aman, unduh hanya melalui sumber resmi di bawah ini.

* **Situs Resmi Game**: https://arskhyrebirth.base44.app
* **Situs Resmi Developer**: https://rationatsu.base44.app
* **Dukungan Pengembangan**: https://sociabuzz.com/rationatsu_art/support | https://paypal.me/hikarurationatsu

---

Copyright (c) 2026 Conefox Studio. All Rights Reserved.

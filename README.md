# Hadir.in - Platform Manajemen Event & Tiket Digital 🎫

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Prisma](https://img.shields.io/badge/Prisma-3982CE?style=for-the-badge&logo=Prisma&logoColor=white)](https://prisma.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)

**Hadir.in** adalah solusi manajemen event modern (Gen-Z oriented) yang dirancang untuk mempermudah pendaftaran, distribusi tiket, dan absensi kehadiran menggunakan QR Code secara real-time.

## ✨ Fitur Utama

- **Event Dashboard**: Kelola banyak event dalam satu akun dengan statistik kehadiran yang intuitif.
- **Visual Range Blast Email**: Kirim tiket ke ribuan peserta dengan memilih rentang secara visual (drag/tap selection). Jauh lebih instan dibanding input manual.
- **Dynamic Ticket Template**: Kustomisasi letak Nama dan QR Code di atas e-ticket sesuai keinginan organizer.
- **Geofencing Check-in**: Validasi kehadiran berdasarkan lokasi (radius meter) untuk mencegah kecurangan absen.
- **Self Check-in**: Peserta dapat melakukan absen secara mandiri dengan memindai QR di lokasi.
- **Invitation System**: Undang panitia/volunteer ke event Anda dengan link unik.

## 📷 App Showcase

Berikut adalah tampilan antarmuka aplikasi Hadir.in saat ini (Tahap Pengembangan):

<p align="center">
  <img src="showcase.png" width="300" alt="Hadir.in Top-up UI">
  <br>
  <i>Tampilan Dialog Top-up Quota Email</i>
</p>

## 🚀 Struktur Proyek

Proyek ini menggunakan arsitektur Monorepo sederhana:

- `/hadir_in_api`: Backend menggunakan Node.js, Express, dan Prisma ORM.
- `/hadir_in_app`: Frontend Mobile menggunakan Flutter dengan BLoC state management.

## 🛠️ Stack Teknologi

### Backend (API)

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: PostgreSQL (Prisma ORM)
- **Image Processing**: Sharp (untuk generate ticket dinamis)
- **Mail Service**: Nodemailer (SMTP)

### Frontend (App)

- **Framework**: Flutter (Dart)
- **State Management**: BLoC (Business Logic Component)
- **Network**: Dio
- **Storage**: Flutter Secure Storage (untuk token JWT)
- **Theme**: Custom Modern UI Theme (Coral & Cream)

## 📋 Syarat & Ketentuan (T&C)

Penting bagi seluruh Organizer untuk membaca dan memahami aturan penggunaan platform, terutama mengenai kebijakan kuota email dan data peserta.
Detail lengkap dapat dibaca di: **[Syarat & Ketentuan Layanan (TERMS.md)](TERMS.md)**

## 🔧 Instalasi

### 1. Backend Setup

```bash
cd hadir_in_api
npm install
npx prisma generate
# Atur .env (DATABASE_URL, JWT_SECRET, SMTP_CONFIG)
npm start
```

### 2. Frontend Setup

```bash
cd hadir_in_app
flutter pub get
# Atur API URL di lib/core/constants/api_config.dart
flutter run
```

---

Dibuat oleh **[Ihsan Hadi](https://github.com/ihsanhadi57)**

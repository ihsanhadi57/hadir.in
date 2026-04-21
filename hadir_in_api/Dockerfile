# --- STAGE 1: Build ---
FROM node:18-alpine AS builder

# Install library pendukung untuk 'sharp' (image processing) dan build tools
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Salin package.json dan package-lock.json
COPY package*.json ./

# Install SEMUA dependensi (termasuk devDeps untuk prisma)
RUN npm install

# Salin source code dan folder prisma
COPY . .

# Generate Prisma Client (Wajib dilakukan agar library prisma bisa jalan)
RUN npx prisma generate

# Kita bisa hapus devDependencies di sini untuk mengecilkan node_modules, 
# tapi hati-hati jangan sampai prisma client hilang.
# Untuk keamanan, kita lanjut ke stage berikutnya saja.

# --- STAGE 2: Run ---
FROM node:18-alpine AS runner

# Tentukan environment
ENV NODE_ENV=production

WORKDIR /app

# Salin hanya node_modules yang sudah di-generate dari stage builder
COPY --from=builder /app/node_modules ./node_modules
# Salin source code
COPY --from=builder /app ./

# Pastikan folder uploads tersedia untuk file sementara
RUN mkdir -p uploads

# Port default yang digunakan Express
EXPOSE 4000

# Script start:
# 1. 'npx prisma migrate deploy' Sinkronisasi schema ke DB Cloud (Supabase/Neon/dll)
# 2. 'npm start' Menjalankan server
CMD npx prisma migrate deploy && npm start

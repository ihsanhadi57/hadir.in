const prisma = require('../config/prisma');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const emailService = require('../services/emailService');

const googleClient = new OAuth2Client();

// Audience yang diterima: Web Dashboard + Firebase Web Client (untuk mobile)
const GOOGLE_AUDIENCES = [
    process.env.GOOGLE_CLIENT_ID,                // Web Dashboard (untuk login web)
    process.env.GOOGLE_CLIENT_ID_MOBILE,          // Firebase Web Client (untuk login mobile)
].filter(Boolean); // Hapus undefined jika env tidak diset

// ─── Helper: Strip password from user object ───
const sanitizeUser = (user) => {
    const { password: _, ...safe } = user;
    return safe;
};

const register = async (req, res) => {
    try {
        const { name, email, password, role } = req.body;

        if (!name || !email || !password) {
            return res.status(400).json({
                status: "error",
                message: "Name, email, dan password wajib diisi."
            });
        }

        const existingUser = await prisma.user.findUnique({ where: { email } });
        if (existingUser) {
            return res.status(400).json({ status: "error", message: "Email sudah terdaftar." });
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Generate OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 menit

        const newUser = await prisma.user.create({
            data: {
                name,
                email,
                password: hashedPassword,
                role: role || 'organizer',
                emailQuota: 0, // 0 until verified
                totalEmailsSent: 0,
                isVerified: false,
                otpCode,
                otpExpires
            }
        });

        // Kirim OTP via Email
        await emailService.sendOTPEmail(email, otpCode).catch(err => {
            console.error("Gagal kirim OTP saat registrasi:", err.message);
        });

        return res.status(201).json({
            status: "success",
            message: "Registrasi berhasil.",
            data: sanitizeUser(newUser)
        });

    } catch (error) {
        console.error("Error di register:", error);
        return res.status(500).json({ status: "error", message: "Terjadi kesalahan pada server." });
    }
};

const login = async (req, res) => {
    try {
        const { email, password } = req.body;

        // Validasi input
        if (!email || !password) {
            return res.status(400).json({ status: "error", message: "Email dan password wajib diisi." });
        }

        const user = await prisma.user.findUnique({ where: { email } });
        if (!user) {
            return res.status(404).json({ status: "error", message: "Akun belum terdaftar." });
        }

        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            return res.status(401).json({ status: "error", message: "Email atau password salah." });
        }

        const token = jwt.sign(
            { id: user.id, email: user.email, role: user.role },
            process.env.JWT_SECRET || 'rahasia_super_aman_jwt_123',
            { expiresIn: '30d' }
        );

        return res.status(200).json({
            status: "success",
            message: "Login berhasil.",
            data: {
                user: sanitizeUser(user),
                token
            }
        });

    } catch (error) {
        console.error("Error di login:", error);
        return res.status(500).json({ status: "error", message: "Terjadi kesalahan pada server." });
    }
};

const googleLogin = async (req, res) => {
    try {
        const { idToken } = req.body;
        if (!idToken) {
            return res.status(400).json({ status: "error", message: "Token Google tidak ditemukan." });
        }

        const ticket = await googleClient.verifyIdToken({
            idToken,
            audience: GOOGLE_AUDIENCES.length > 0 ? GOOGLE_AUDIENCES : undefined,
        });
        const payload = ticket.getPayload();
        const email = payload.email;
        const name = payload.name;
        const picture = payload.picture; // URL foto profil dari Google

        if (!email) {
            return res.status(400).json({ status: "error", message: "Gagal mendapatkan email dari Google." });
        }

        let user = await prisma.user.findUnique({ where: { email } });

        if (!user) {
            const salt = await bcrypt.genSalt(10);
            const randomPassword = require('crypto').randomBytes(32).toString('hex');
            const hashedPassword = await bcrypt.hash(randomPassword, salt);

            user = await prisma.user.create({
                data: {
                    name,
                    email,
                    password: hashedPassword,
                    role: 'organizer',
                    emailQuota: 50, // Google login is pre-verified
                    totalEmailsSent: 0,
                    avatarUrl: picture,
                    isVerified: true, // Google accounts are verified
                }
            });
        } else {
            // Update foto jika berubah (opsional, untuk sinkronisasi)
            if (picture && user.avatarUrl !== picture) {
                user = await prisma.user.update({
                    where: { id: user.id },
                    data: { avatarUrl: picture }
                });
            }
        }

        const token = jwt.sign(
            { id: user.id, email: user.email, role: user.role },
            process.env.JWT_SECRET || 'rahasia_super_aman_jwt_123',
            { expiresIn: '30d' }
        );

        return res.status(200).json({
            status: "success",
            message: "Login Google berhasil.",
            data: sanitizeUser(user),
            token
        });

    } catch (error) {
        console.error("Error di googleLogin:", error);
        return res.status(401).json({ status: "error", message: "Verifikasi Google Gagal atau Token Expired." });
    }
};

// ─── GET /auth/me ─── Ambil profil user yang sedang login ───
const getMe = async (req, res) => {
    try {
        const user = await prisma.user.findUnique({
            where: { id: req.user.id }
        });

        if (!user) {
            return res.status(404).json({ status: "error", message: "User tidak ditemukan." });
        }

        return res.status(200).json({
            status: "success",
            data: sanitizeUser(user)
        });
    } catch (error) {
        console.error("Error di getMe:", error);
        return res.status(500).json({ status: "error", message: "Terjadi kesalahan pada server." });
    }
};

// ─── PUT /auth/profile ─── Update nama & password user ───
const updateProfile = async (req, res) => {
    try {
        const { name, currentPassword, newPassword } = req.body;

        const user = await prisma.user.findUnique({ where: { id: req.user.id } });
        if (!user) {
            return res.status(404).json({ status: "error", message: "User tidak ditemukan." });
        }

        const updateData = {};

        // Update nama jika disertakan
        if (name && name.trim()) {
            updateData.name = name.trim();
        }

        // Update password jika kedua field disertakan
        if (currentPassword && newPassword) {
            const isPasswordValid = await bcrypt.compare(currentPassword, user.password);
            if (!isPasswordValid) {
                return res.status(401).json({ status: "error", message: "Password lama tidak sesuai." });
            }
            if (newPassword.length < 8) {
                return res.status(400).json({ status: "error", message: "Password baru minimal 8 karakter." });
            }
            const salt = await bcrypt.genSalt(10);
            updateData.password = await bcrypt.hash(newPassword, salt);
        }

        if (Object.keys(updateData).length === 0) {
            return res.status(400).json({ status: "error", message: "Tidak ada data yang diubah." });
        }

        const updated = await prisma.user.update({
            where: { id: req.user.id },
            data: updateData
        });

        return res.status(200).json({
            status: "success",
            message: "Profil berhasil diperbarui.",
            data: sanitizeUser(updated)
        });
    } catch (error) {
        console.error("Error di updateProfile:", error);
        return res.status(500).json({ status: "error", message: "Gagal memperbarui profil." });
    }
};

const verifyOTP = async (req, res) => {
    try {
        const { email, otp } = req.body;

        if (!email || !otp) {
            return res.status(400).json({ status: "error", message: "Email dan kode OTP wajib diisi." });
        }

        const user = await prisma.user.findUnique({ where: { email } });

        if (!user) {
            return res.status(404).json({ status: "error", message: "User tidak ditemukan." });
        }

        if (user.isVerified) {
            return res.status(400).json({ status: "error", message: "Akun sudah terverifikasi." });
        }

        // Cek OTP & Expiry
        if (user.otpCode !== otp) {
            return res.status(400).json({ status: "error", message: "Kode OTP salah." });
        }

        if (user.otpExpires < new Date()) {
            return res.status(400).json({ status: "error", message: "Kode OTP sudah kadaluarsa. Silakan request kode baru." });
        }

        // Verifikasi Akun & Kasih Quota
        const updatedUser = await prisma.user.update({
            where: { id: user.id },
            data: {
                isVerified: true,
                emailQuota: 50, // Kuota awal bonus verifikasi
                otpCode: null,
                otpExpires: null
            }
        });

        // Generate Token Baru agar user bisa langsung masuk
        const token = jwt.sign(
            { id: updatedUser.id, email: updatedUser.email, role: updatedUser.role },
            process.env.JWT_SECRET || 'rahasia_super_aman_jwt_123',
            { expiresIn: '30d' }
        );

        return res.status(200).json({
            status: "success",
            message: "Akun berhasil diverifikasi! Selamat datang.",
            data: {
                user: sanitizeUser(updatedUser),
                token
            }
        });

    } catch (error) {
        console.error("Error di verifyOTP:", error);
        return res.status(500).json({ status: "error", message: "Gagal verifikasi OTP." });
    }
};

module.exports = {
    register,
    login,
    googleLogin,
    getMe,
    updateProfile,
    verifyOTP,
};

const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

// Route untuk registrasi user
router.post('/register', authController.register);

// Route untuk login user
router.post('/login', authController.login);

// Route untuk login via Google
router.post('/google', authController.googleLogin);

// Route untuk verifikasi OTP
router.post('/verify-otp', authController.verifyOTP);

// Route untuk kirim ulang OTP (jika kadaluarsa)
router.post('/resend-otp', authController.resendOTP);

// ─── Protected Routes (butuh JWT) ───
// Ambil profil user yang sedang login
router.get('/me', authMiddleware, authController.getMe);

// Update profil user (nama & password)
router.put('/profile', authMiddleware, authController.updateProfile);

module.exports = router;

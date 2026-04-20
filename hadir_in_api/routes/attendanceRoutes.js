const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
const authMiddleware = require('../middleware/authMiddleware');

const multer = require('multer');

// Setup multer untuk menyimpan foto self check-in
const upload = multer({ dest: 'uploads/attendance/' });

// Rute public: Peserta absen mandiri (tanpa login akun)
router.post('/self-checkin/:eventId', upload.single('photo'), attendanceController.selfCheckIn);

// Semua rute attendance di bawah ini memerlukan login (Scanner/Organizer)
router.use(authMiddleware);

router.post('/scan', attendanceController.scanTicket);
router.get('/:eventId', attendanceController.getAttendanceLogs);
router.delete('/logs/:logId', attendanceController.deleteLog);

module.exports = router;

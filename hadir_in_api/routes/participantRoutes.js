const express = require('express');
const router = express.Router();
const multer = require('multer');
const participantController = require('../controllers/participantController');
const authMiddleware = require('../middleware/authMiddleware');

// Konfigurasi Multer untuk penyimpanan sementara
const upload = multer({ dest: 'uploads/' });

// Route publik (tanpa login) — Download template CSV
router.get('/template/csv', participantController.downloadTemplate);

// Semua rute peserta di bawah ini memerlukan login
router.use(authMiddleware);

// Rute manual & bulk bisa diakses siapa saja yang punya token valid
router.post('/manual', participantController.registerManual);
router.post('/bulk', upload.single('file'), participantController.registerBulk);

// Mengambil daftar participant sebuah event
router.get('/:eventId', participantController.getParticipants);

// Update data peserta
router.put('/:id', participantController.updateParticipant);

// Hapus peserta
router.delete('/:id', participantController.deleteParticipant);

// Kirim tiket ke 1 peserta
router.post('/:id/send-ticket', participantController.sendTicket);

// Mengirimkan E-Ticket massal ke seluruh peserta sebuah event
router.post('/:eventId/blast', participantController.blastTickets);

module.exports = router;

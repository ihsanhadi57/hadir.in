const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const authMiddleware = require('../middleware/authMiddleware');

// Semua rute dashboard memerlukan login (Organizer)
router.use(authMiddleware);

router.get('/:eventId/stats', dashboardController.getEventStats);

module.exports = router;

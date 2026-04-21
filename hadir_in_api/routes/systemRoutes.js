const express = require('express');
const router = express.Router();
const systemController = require('../controllers/systemController');

// Endpoint pembersihan otomatis (H+3)
// Trigger: External Cron (e.g. cron-job.org) ping ke /api/system/cleanup?secret=...
router.get('/cleanup', systemController.runCleanup);

module.exports = router;

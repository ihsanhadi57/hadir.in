const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const authMiddleware = require('../middleware/authMiddleware');

// Public Webhook (No auth required because Midtrans calls this)
router.post('/webhook', paymentController.handleWebhook);

// Protected routes (Require login)
router.post('/create-snap', authMiddleware, paymentController.createSnapTransaction);

module.exports = router;

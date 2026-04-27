const midtransClient = require('midtrans-client');
const prisma = require('../config/prisma');
const crypto = require('crypto');

// Initialize Midtrans Snap client
let snap = new midtransClient.Snap({
    isProduction: process.env.MIDTRANS_IS_PRODUCTION === 'true',
    serverKey: process.env.MIDTRANS_SERVER_KEY,
    clientKey: process.env.MIDTRANS_CLIENT_KEY
});

const createSnapTransaction = async (req, res) => {
    try {
        const { quota, amount } = req.body;
        const userId = req.user.id;

        if (!quota || !amount) {
            return res.status(400).json({ status: 'error', message: 'Quota dan harga wajib diisi.' });
        }

        // Generate Order ID (Max 50 chars for Midtrans)
        // Format: TO-TIMESTAMP-USERID
        const orderId = `TO-${Date.now()}-${userId.substring(0, 8)}`;

        // Save to Database
        await prisma.topupTransaction.create({
            data: {
                userId,
                orderId,
                amount,
                quota,
                status: 'pending'
            }
        });

        // Create Snap Parameter
        let parameter = {
            "transaction_details": {
                "order_id": orderId,
                "gross_amount": amount
            },
            "customer_details": {
                "first_name": req.user.name,
                "email": req.user.email
            },
            "item_details": [
                {
                    "id": `QUOTA-${quota}`,
                    "price": amount,
                    "quantity": 1,
                    "name": `Top-up ${quota} Email Quota`
                }
            ],
            // Redirect back to app (will be handled by Flutter AppLinks if configured)
            "callbacks": {
                "finish": "hadirin://payment/finish",
                "error": "hadirin://payment/error"
            }
        };

        const snapResponse = await snap.createTransaction(parameter);

        // Update transaction with snapToken
        await prisma.topupTransaction.update({
            where: { orderId },
            data: { snapToken: snapResponse.token }
        });

        return res.status(200).json({
            status: 'success',
            data: {
                token: snapResponse.token,
                redirect_url: snapResponse.redirect_url,
                orderId
            }
        });

    } catch (error) {
        console.error("Error createSnapTransaction:", error);
        return res.status(500).json({ status: 'error', message: 'Gagal membuat transaksi pembayaran.' });
    }
};

const handleWebhook = async (req, res) => {
    try {
        const notificationJson = req.body;
        console.log(`\n[Midtrans Webhook] RAW INCOMING REQUEST:`, JSON.stringify(notificationJson));

        // Verify Signature
        // Reference: https://docs.midtrans.com/en/after-payment/http-notification?id=signature-key-verification
        const { order_id, status_code, gross_amount, signature_key } = notificationJson;
        const serverKey = process.env.MIDTRANS_SERVER_KEY;
        
        const payload = order_id + status_code + gross_amount + serverKey;
        const expectedSignature = crypto.createHash('sha512').update(payload).digest('hex');

        if (signature_key !== expectedSignature) {
            console.error(`[Midtrans Webhook] SIGNATURE MISMATCH! Expected: ${expectedSignature}, Received: ${signature_key}. OrderID: ${order_id}`);
            return res.status(401).json({ status: 'error', message: 'Invalid Signature' });
        }

        const transactionStatus = notificationJson.transaction_status;
        const fraudStatus = notificationJson.fraud_status;

        console.log(`[Midtrans Webhook] Verification Success. Order ID: ${order_id}. Status: ${transactionStatus}. Fraud: ${fraudStatus}`);

        // Find transaction
        const transaction = await prisma.topupTransaction.findUnique({
            where: { orderId: order_id }
        });

        if (!transaction) {
            console.log(`[Midtrans Webhook] Info: Order ID ${order_id} not found in database. Skipping...`);
            return res.status(200).json({ status: 'success', message: 'Notification received but order not found' });
        }

        // Handle Status logic
        // Reference: https://docs.midtrans.com/en/after-payment/http-notification?id=transaction-status-redirection-to-callback-url
        let newStatus = transaction.status;

        if (transactionStatus == 'capture') {
            if (fraudStatus == 'challenge') {
                newStatus = 'challenge';
            } else if (fraudStatus == 'accept') {
                newStatus = 'settlement';
            }
        } else if (transactionStatus == 'settlement') {
            newStatus = 'settlement';
        } else if (transactionStatus == 'cancel' || transactionStatus == 'deny' || transactionStatus == 'expire') {
            newStatus = 'failure';
        } else if (transactionStatus == 'pending') {
            newStatus = 'pending';
        }

        // Update Transaction status
        // Only update if not already settled or fraudulent
        const updatedTransaction = await prisma.topupTransaction.update({
            where: { orderId: order_id },
            data: { status: newStatus }
        });

        // CRITICAL: If status became settlement AND it wasn't already settlement, increment user's quota.
        if (newStatus === 'settlement' && transaction.status !== 'settlement') {
            await prisma.user.update({
                where: { id: transaction.userId },
                data: {
                    emailQuota: { increment: transaction.quota }
                }
            });
            console.log(`[Midtrans Webhook] SUCCESS: Quota +${transaction.quota} added to User ID: ${transaction.userId}`);
        }

        return res.status(200).json({ status: 'success', message: 'Notification processed successfully' });

    } catch (error) {
        console.error("Error handleWebhook:", error);
        return res.status(500).json({ status: 'error', message: 'Internal Server Error processing webhook' });
    }
};

const getHistory = async (req, res) => {
    try {
        const userId = req.user.id;

        const transactions = await prisma.topupTransaction.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });

        return res.status(200).json({
            status: 'success',
            data: transactions
        });
    } catch (error) {
        console.error("Error getHistory:", error);
        return res.status(500).json({ status: 'error', message: 'Gagal mengambil riwayat transaksi.' });
    }
};

module.exports = {
    createSnapTransaction,
    handleWebhook,
    getHistory
};

process.on('uncaughtException', (err) => {
    console.error('UNCAUGHT EXCEPTION:', err)
    // JANGAN process.exit(1) — menyebabkan server restart dan disconnect socket
})

process.on('unhandledRejection', (reason) => {
    console.error('UNHANDLED REJECTION:', reason)
    // JANGAN process.exit(1) — menyebabkan server restart dan disconnect socket
})

const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();
const prisma = require('./config/prisma');

const app = express();

// ─── Buat HTTP server untuk Express + Socket.IO ───
const server = http.createServer(app);

// ─── Setup Socket.IO ───
const io = new Server(server, {
    cors: {
        origin: '*', // Allow semua origin (Flutter, web, dll)
        methods: ['GET', 'POST'],
    },
    // Render.com handle SSL, jadi tidak perlu konfigurasi TLS di sini
    pingTimeout: 60000,
    pingInterval: 25000,
});

// Simpan io instance secara global agar bisa dipakai di controller
global.io = io;

// ─── Socket.IO Event Handlers ───
io.on('connection', (socket) => {
    console.log(`🔌 Socket connected: ${socket.id}`);

    // Client join ke room event tertentu
    socket.on('joinEvent', (eventId) => {
        socket.join(`event:${eventId}`);
        console.log(`📡 Socket ${socket.id} joined room event:${eventId}`);
    });

    // Client leave dari room event
    socket.on('leaveEvent', (eventId) => {
        socket.leave(`event:${eventId}`);
        console.log(`📡 Socket ${socket.id} left room event:${eventId}`);
    });

    // Client join ke room user (untuk event list updates)
    socket.on('joinUserRoom', (userId) => {
        socket.join(`user:${userId}`);
        console.log(`📡 Socket ${socket.id} joined room user:${userId}`);
    });

    // Client leave dari room user
    socket.on('leaveUserRoom', (userId) => {
        socket.leave(`user:${userId}`);
        console.log(`📡 Socket ${socket.id} left room user:${userId}`);
    });

    socket.on('disconnect', (reason) => {
        console.log(`⚠️ Socket disconnected: ${socket.id} — ${reason}`);
    });
});

// Middleware
// cors() mengizinkan aplikasi Flutter kita nanti untuk mengakses API ini
app.use(cors());
app.use(express.json());
// Serve uploaded files (template images) publicly
app.use('/uploads', express.static('uploads'));
app.use(express.static('public'));

// Routes import
const authRoutes = require('./routes/authRoutes');
const eventRoutes = require('./routes/eventRoutes');
const participantRoutes = require('./routes/participantRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const systemRoutes = require('./routes/systemRoutes');
const attendanceController = require('./controllers/attendanceController');

// Route Landing Page Profesional
app.get('/', (req, res) => {
    const path = require('path');
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Route Web Dashboard (SPA catch-all)
app.get('/app/dashboard.html', (req, res) => {
    const path = require('path');
    res.sendFile(path.join(__dirname, 'public', 'app', 'dashboard.html'));
});

// Route Self Check-in Landing Page
app.get('/attend/:eventId', attendanceController.renderSelfCheckInPage);

// Route Invitation Landing Page
app.get('/invite/:code', async (req, res) => {
    const { code } = req.params;

    try {
        const event = await prisma.event.findUnique({
            where: { inviteCode: code },
            include: { organizer: true }
        });

        if (!event) {
            return res.status(404).send('<h1>Event tidak ditemukan atau link tidak valid.</h1>');
        }

        const deepLink = `hadirin://invite?code=${code}`;

        const html = `
        <!DOCTYPE html>
        <html lang="id">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Undangan Panitia Hadir.in</title>
            <style>
                body { font-family: 'Inter', sans-serif; background-color: #F9FAFB; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
                .card { background: white; padding: 32px; border-radius: 24px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1); width: 90%; max-width: 400px; text-align: center; }
                .badge { background: #E0E7FF; color: #4338CA; padding: 6px 16px; border-radius: 20px; font-size: 14px; font-weight: bold; display: inline-block; margin-bottom: 16px; }
                h1 { color: #111827; font-size: 24px; margin: 0 0 8px 0; }
                p { color: #6B7280; font-size: 15px; line-height: 1.5; margin-bottom: 32px; }
                .btn { display: inline-block; background: #004AC6; color: white; text-decoration: none; padding: 16px 32px; border-radius: 12px; font-weight: bold; width: 100%; box-sizing: border-box; box-shadow: 0 4px 6px -1px rgba(0, 74, 198, 0.4); transition: transform 0.2s; }
                .btn:active { transform: scale(0.98); }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="badge">Undangan Panitia</div>
                <h1>${event.name}</h1>
                <p>Klik tombol di bawah ini untuk membuka aplikasi <b>Hadir.in</b> dan bergabung sebagai panitia resmi event.</p>
                <a href="${deepLink}" class="btn">Buka Hadir.in</a>
            </div>
        </body>
        </html>
        `;

        res.send(html);
    } catch (err) {
        res.status(500).send('Terjadi kesalahan server.');
    }
});

// Routes Registration
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/participants', participantRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/payment', paymentRoutes);
app.use('/api/system', systemRoutes);

// ─── Menjalankan Server (HTTP + Socket.IO) ───
const PORT = process.env.PORT || 4000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server + Socket.IO berjalan di http://localhost:${PORT}`);
});
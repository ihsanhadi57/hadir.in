process.on('uncaughtException', (err) => {
    console.error('UNCAUGHT EXCEPTION:', err)
    process.exit(1)
})

process.on('unhandledRejection', (reason) => {
    console.error('UNHANDLED REJECTION:', reason)
    process.exit(1)
})

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
require('dotenv').config();
const prisma = require('./config/prisma');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Share io instance to all routes
app.set('io', io);
global.io = io;

// Socket.io connection logic
io.on('connection', (socket) => {
    console.log('User connected:', socket.id);

    // Join room for specific event to avoid broadcasting to everyone
    socket.on('joinEvent', (eventId) => {
        socket.join(eventId);
        console.log(`Socket ${socket.id} joined event room: ${eventId}`);
    });

    socket.on('disconnect', () => {
        console.log('User disconnected:', socket.id);
    });
});

// Middleware
// cors() mengizinkan aplikasi Flutter kita nanti untuk mengakses API ini
app.use(cors());
app.use(express.json());
// Serve uploaded files (template images) publicly
app.use('/uploads', express.static('uploads'));
app.use('/public', express.static('public'));

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
    const html = `
    <!DOCTYPE html>
    <html lang="id">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hadir.in - Smart Attendance System</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&display=swap" rel="stylesheet">
        <style>
            :root {
                --primary: #FF5F5F; /* Coral */
                --secondary: #004AC6; /* Blue */
                --bg: #FFFBF5; /* Cream */
                --text: #1F2937;
            }
            body { 
                font-family: 'Outfit', sans-serif; 
                background-color: var(--bg); 
                color: var(--text);
                margin: 0;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                overflow: hidden;
            }
            .container {
                text-align: center;
                padding: 40px;
                max-width: 600px;
                position: relative;
                z-index: 1;
            }
            .logo-img {
                width: 120px;
                height: 120px;
                object-fit: contain;
                margin: 0 auto 24px;
                display: block;
                filter: drop-shadow(0 15px 30px rgba(255, 95, 95, 0.2));
                animation: float 6s ease-in-out infinite;
            }
            h1 { font-size: 48px; font-weight: 800; margin: 0; letter-spacing: -1px; color: var(--secondary); }
            span.highlight { color: var(--primary); }
            p { font-size: 18px; color: #6B7280; line-height: 1.6; margin: 16px 0 32px; }
            .badge {
                background: white;
                padding: 8px 16px;
                border-radius: 100px;
                font-size: 14px;
                font-weight: 600;
                color: var(--secondary);
                box-shadow: 0 4px 6px rgba(0,0,0,0.05);
                display: inline-block;
                margin-bottom: 20px;
            }
            .status-dot {
                width: 8px;
                height: 8px;
                background: #10B981;
                border-radius: 50%;
                display: inline-block;
                margin-right: 8px;
                box-shadow: 0 0 10px #10B981;
            }
            .grid-bg {
                position: absolute;
                top: 0; left: 0; right: 0; bottom: 0;
                background-image: radial-gradient(#FF5F5F22 1px, transparent 1px);
                background-size: 40px 40px;
                z-index: 0;
            }
            @keyframes float {
                0% { transform: translateY(0px) rotate(-5deg); }
                50% { transform: translateY(-20px) rotate(5deg); }
                100% { transform: translateY(0px) rotate(-5deg); }
            }
            .btn-group { display: flex; gap: 12px; justify-content: center; }
            .btn {
                text-decoration: none;
                padding: 14px 28px;
                border-radius: 14px;
                font-weight: 600;
                transition: all 0.3s;
            }
            .btn-primary { background: var(--secondary); color: white; box-shadow: 0 10px 20px rgba(0, 74, 198, 0.2); }
            .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 15px 30px rgba(0, 74, 198, 0.3); }
        </style>
    </head>
    <body>
        <div class="grid-bg"></div>
        <div class="container">
            <div class="badge"><span class="status-dot"></span> API Server Online</div>
            <img src="/public/logo-no-bg.png" alt="Hadir.in Logo" class="logo-img">
            <h1>Hadir<span class="highlight">.in</span></h1>
            <p>Sistem Manajemen Kehadiran & Ticketing Event Pintar berbasis Cloud. Kelola ribuan peserta hanya dalam genggaman tangan.</p>
            <div class="btn-group">
                <a href="#" class="btn btn-primary">Download App</a>
            </div>
        </div>
    </body>
    </html>
    `;
    res.send(html);
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

// Menjalankan Server
const PORT = process.env.PORT || 4000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server sudah berjalan di http://localhost:${PORT}`);
});
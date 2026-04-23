const prisma = require('../config/prisma');
const { cloudinary } = require('../config/cloudinary');

const scanTicket = async (req, res) => {
    try {
        const { ticketId, eventId, latitude, longitude, photoUrl } = req.body;

        if (!ticketId || !eventId) {
            return res.status(400).json({
                status: "error",
                message: "Ticket ID dan Event ID wajib disertakan."
            });
        }

        // 1. Cari peserta dan pastikan terdaftar di event yang benar
        const participant = await prisma.participant.findFirst({
            where: {
                ticketId,
                eventId
            },
            include: {
                event: true,
                logs: {
                    orderBy: { scannedAt: 'desc' },
                    take: 1
                }
            }
        });

        if (!participant) {
            return res.status(404).json({
                status: "error",
                message: "Tiket tidak terdaftar atau tidak sesuai dengan event ini."
            });
        }

        // 2. Verifikasi kepemilikan event (Organizer yang scan harus pemilik event atau masuk committee)
        if (participant.event.organizerId !== req.user.id) {
            const committee = await prisma.eventCommittee.findUnique({
                where: { eventId_userId: { eventId, userId: req.user.id } }
            });
            if (!committee) {
                return res.status(403).json({
                    status: "error",
                    message: "Anda tidak memiliki otoritas untuk men-scan tiket event ini."
                });
            }
        }

        // 3. Cek apakah sudah pernah di-scan (Strict: 1x Scan Only)
        if (participant.status === 'used') {
            const lastLog = participant.logs[0];
            return res.status(400).json({
                status: "error",
                message: "Tiket sudah digunakan sebelumnya.",
                scannedAt: lastLog ? lastLog.scannedAt : null
            });
        }

        // 4. Catat Log Kehadiran dan Update Status Peserta
        // Gunakan transaction untuk memastikan integritas data
        const result = await prisma.$transaction([
            prisma.attendanceLog.create({
                data: {
                    eventId,
                    participantId: participant.id,
                    scannedById: req.user.id,
                    latitude: latitude ? parseFloat(latitude) : null,
                    longitude: longitude ? parseFloat(longitude) : null,
                    photoUrl: photoUrl || null
                }
            }),
            prisma.participant.update({
                where: { id: participant.id },
                data: { status: 'used' }
            })
        ]);

        // ─── Emit Socket.IO event ke semua client di room event ini ───
        if (global.io) {
            global.io.to(`event:${eventId}`).emit('attendanceUpdated', { eventId });
            console.log(`📡 Socket: attendanceUpdated emitted for event:${eventId}`);
        }


        return res.status(200).json({
            status: "success",
            message: "Check-in berhasil! Selamat datang.",
            data: {
                participantName: participant.name,
                scannedAt: result[0].scannedAt
            }
        });

    } catch (error) {
        console.error("Error scanTicket:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan pada server saat proses scan."
        });
    }
};

const getAttendanceLogs = async (req, res) => {
    try {
        const { eventId } = req.params;

        // Pastikan event milik organizer atau panitia
        const event = await prisma.event.findFirst({
            where: {
                id: eventId,
                OR: [
                    { organizerId: req.user.id },
                    { committees: { some: { userId: req.user.id } } }
                ]
            }
        });

        if (!event) {
            return res.status(403).json({
                status: "error",
                message: "Anda tidak memiliki akses ke log event ini."
            });
        }

        const logs = await prisma.attendanceLog.findMany({
            where: { eventId },
            orderBy: { scannedAt: 'desc' },
            include: {
                participant: {
                    select: { name: true, email: true, ticketId: true }
                }
            }
        });

        return res.status(200).json({
            status: "success",
            data: logs
        });
    } catch (error) {
        console.error("Error getAttendanceLogs:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat mengambil log kehadiran."
        });
    }
};

// ─── Haversine formula: menghitung jarak antara 2 titik koordinat (meter) ───
function haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000; // Radius bumi dalam meter
    const toRad = (deg) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

const GEOFENCE_RADIUS_METERS = 200; // Toleransi 200 meter

// ─── Self Check-In (Peserta via Web) ───
const selfCheckIn = async (req, res) => {
    try {
        const { eventId } = req.params;
        const { name, email, latitude, longitude, requirePhoto } = req.body;

        if (!name) {
            return res.status(400).json({ status: "error", message: "Nama wajib diisi." });
        }

        // Cek apakah photo wajib butuh
        if (requirePhoto === 'true' && !req.file) {
            return res.status(400).json({ status: "error", message: "Foto wajah wajib diambil." });
        }

        // Cek apakah event valid
        const event = await prisma.event.findUnique({ where: { id: eventId } });
        if (!event) {
            return res.status(404).json({ status: "error", message: "Event tidak ditemukan." });
        }

        // ─── Geofencing: Validasi jarak peserta dari lokasi event ───
        if (event.latitude != null && event.longitude != null) {
            if (!latitude || !longitude) {
                return res.status(400).json({
                    status: "error",
                    message: "Lokasi GPS kamu diperlukan untuk absensi. Pastikan izin lokasi aktif."
                });
            }

            const distance = haversineDistance(
                parseFloat(latitude),
                parseFloat(longitude),
                event.latitude,
                event.longitude
            );

            if (distance > GEOFENCE_RADIUS_METERS) {
                return res.status(403).json({
                    status: "error",
                    message: `Kamu terlalu jauh dari lokasi acara (${Math.round(distance)}m). Maksimal ${GEOFENCE_RADIUS_METERS}m dari titik event.`
                });
            }
        }

        // Gunakan email yang didapat atau generate dummy jika kosong
        const finalEmail = email ? email : `${Date.now()}-${Math.random().toString(36).substr(2, 5)}@self.hadir.in`;
        let photoUrl = null;

        if (req.file) {
            // req.file.path adalah URL Cloudinary yang sudah diproses oleh multer-storage-cloudinary
            photoUrl = req.file.path;
        }

        // Cek apakah peserta dengan email yang sama ada di event
        let participant = await prisma.participant.findUnique({
            where: {
                email_eventId: {
                    email: finalEmail,
                    eventId: eventId
                }
            }
        });

        if (!participant) {
            // Belum ada, buat baru
            participant = await prisma.participant.create({
                data: {
                    eventId,
                    name,
                    email: finalEmail,
                    status: 'used', // Langsung dianggap hadir
                }
            });
        } else {
            // Sudah ada, cek apakah sudah check-in
            if (participant.status === 'used') {
                return res.status(400).json({ status: "error", message: "Anda sudah melakukan check-in sebelumnya." });
            }
            // Update status menjadi hadir
            participant = await prisma.participant.update({
                where: { id: participant.id },
                data: { status: 'used' }
            });
        }

        // Simpan log absensi
        const log = await prisma.attendanceLog.create({
            data: {
                eventId,
                participantId: participant.id,
                latitude: latitude ? parseFloat(latitude) : null,
                longitude: longitude ? parseFloat(longitude) : null,
                photoUrl: photoUrl
            }
        });

        // ─── Emit Socket.IO event ke semua client di room event ini ───
        if (global.io) {
            global.io.to(`event:${eventId}`).emit('attendanceUpdated', { eventId });
            console.log(`📡 Socket: attendanceUpdated emitted for event:${eventId} (self-checkin)`);
        }


        return res.status(200).json({
            status: "success",
            message: "Self Check-in berhasil! Terima kasih.",
            data: {
                participantName: participant.name,
                scannedAt: log.scannedAt
            }
        });

    } catch (error) {
        console.error("Error selfCheckIn:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan sistem saat check-in."
        });
    }
};

const renderSelfCheckInPage = async (req, res) => {
    try {
        const { eventId } = req.params;
        const { requirePhoto } = req.query;

        const event = await prisma.event.findUnique({
            where: { id: eventId },
            include: { organizer: true }
        });

        if (!event) {
            return res.status(404).send('<h1>Event tidak ditemukan.</h1>');
        }

        const html = `
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Check-in: ${event.name}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { 
            font-family: 'Plus Jakarta Sans', sans-serif; 
            background-color: #F8F9FE; 
            background-image: radial-gradient(at 0% 0%, rgba(0, 39, 102, 0.05) 0px, transparent 50%), radial-gradient(at 100% 0%, rgba(255, 111, 97, 0.05) 0px, transparent 50%);
        }
        .glass { 
            background: rgba(255, 255, 255, 0.85); 
            backdrop-filter: blur(16px); 
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 255, 255, 0.5); 
            box-shadow: 0 20px 50px rgba(0, 39, 102, 0.08);
        }
        .btn-primary { 
            background: #002766; 
            box-shadow: 0 8px 20px rgba(0, 39, 102, 0.2); 
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); 
        }
        .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 12px 24px rgba(0, 39, 102, 0.25); }
        .btn-primary:active { transform: scale(0.96); }
        .btn-primary:disabled { background: #cbd5e1; box-shadow: none; transform: none; cursor: not-allowed; }
        
        .shimmer { 
            background: linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.6) 50%, rgba(255,255,255,0) 100%); 
            background-size: 200% 100%; 
            animation: shimmer 2s infinite; 
        }
        @keyframes shimmer { 0% { background-position: -200% 0; } 100% { background-position: 200% 0; } }
        
        #video-container { position: relative; width: 100%; aspect-ratio: 1/1; background: #000; border-radius: 24px; overflow: hidden; }
        #video { width: 100%; height: 100%; object-fit: cover; transform: scaleX(-1); }
        #canvas { display: none; }
        
        input:focus { outline: none; border-color: #002766; box-shadow: 0 0 0 4px rgba(0, 39, 102, 0.1); }
        
        .brand-hadir { color: #002766; }
        .brand-in { color: #FF6F61; }
        
        .fade-in { animation: fadeIn 0.6s ease-out forwards; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    </style>
</head>
<body class="min-h-screen py-10 px-6 flex flex-col items-center">
    <div class="w-full max-w-md fade-in">
        <!-- Header with Logo -->
        <div class="flex flex-col items-center mb-10">
            <img src="/public/logo-no-bg.png" alt="Logo" class="h-16 mb-4 drop-shadow-md">
            <h1 class="text-3xl font-extrabold tracking-tight">
                <span class="brand-hadir">hadir</span><span class="brand-in">.in</span>
            </h1>
            <div class="mt-3 px-4 py-1.5 bg-white shadow-sm border border-gray-100 text-[#002766] text-[10px] font-bold rounded-full uppercase tracking-[0.2em]">
                Self Check-in
            </div>
        </div>

        <!-- Success Card -->
        <div id="success-card" class="hidden glass rounded-[2rem] p-10 text-center animate-in fade-in zoom-in duration-500">
            <div class="w-24 h-24 bg-emerald-50 text-emerald-500 rounded-full flex items-center justify-center mx-auto mb-8 shadow-inner">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
                </svg>
            </div>
            <h2 class="text-2xl font-extrabold text-gray-900 mb-3">Absensi Berhasil!</h2>
            <p id="success-message" class="text-gray-500 leading-relaxed mb-10"></p>
            <button onclick="window.location.reload()" class="w-full py-4 rounded-2xl bg-gray-50 font-bold text-gray-600 hover:bg-gray-100 transition-colors">Tutup</button>
        </div>

        <!-- Form Card -->
        <div id="form-card" class="glass rounded-[2.5rem] p-8 space-y-8">
            <div class="text-center">
                <p class="text-[10px] font-extrabold text-blue-400 uppercase tracking-widest mb-1">Event Kamu</p>
                <h3 class="text-xl font-bold text-gray-900">${event.name}</h3>
            </div>

            <!-- Step 1: Location -->
            <div id="location-section" class="p-5 rounded-3xl bg-[#EEF2FF] border border-blue-50 relative overflow-hidden">
                <div class="flex items-center gap-4 relative z-10">
                    <div id="loc-icon" class="w-12 h-12 bg-white text-[#002766] rounded-2xl shadow-sm flex items-center justify-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                        </svg>
                    </div>
                    <div class="flex-1">
                        <p id="loc-title" class="text-xs font-extrabold text-gray-900 uppercase tracking-tight">Mendeteksi Lokasi...</p>
                        <p id="loc-status" class="text-[11px] text-gray-500 font-medium">Mohon izinkan akses GPS</p>
                    </div>
                    <button id="retry-loc" class="hidden w-10 h-10 flex items-center justify-center text-[#002766] bg-white rounded-xl shadow-sm hover:scale-105 transition-transform">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>
            </div>

            <!-- Step 2: Form Details -->
            <div id="form-details" class="space-y-5">
                <div class="group">
                    <label class="block text-[10px] font-extrabold text-gray-400 uppercase tracking-[0.1em] mb-2 px-1">Nama Lengkap</label>
                    <input type="text" id="name" placeholder="Masukkan nama Anda" class="w-full px-5 py-4 rounded-2xl bg-gray-50 border-2 border-gray-50 focus:bg-white transition-all text-gray-900 font-bold placeholder:text-gray-300 placeholder:font-normal">
                </div>
                <div class="group">
                    <label class="block text-[10px] font-extrabold text-gray-400 uppercase tracking-[0.1em] mb-2 px-1">Email (Opsional)</label>
                    <input type="email" id="email" placeholder="contoh@mail.com" class="w-full px-5 py-4 rounded-2xl bg-gray-50 border-2 border-gray-50 focus:bg-white transition-all text-gray-900 font-bold placeholder:text-gray-300 placeholder:font-normal">
                </div>
            </div>

            <!-- Step 3: Photo -->
            ${requirePhoto === 'true' ? `
            <div id="photo-section" class="space-y-4">
                <label class="block text-[10px] font-extrabold text-gray-400 uppercase tracking-[0.1em] px-1">Foto Kehadiran</label>
                <div id="video-container" class="shadow-2xl ring-8 ring-white/50">
                    <video id="video" autoplay playsinline></video>
                    <div id="shutter-overlay" class="absolute inset-0 bg-white opacity-0 transition-opacity"></div>
                    <button id="capture-btn" class="absolute bottom-6 left-1/2 -translate-x-1/2 w-16 h-16 bg-white rounded-full p-1.5 shadow-2xl flex items-center justify-center">
                        <div class="w-full h-full bg-red-500 rounded-full border-4 border-white"></div>
                    </button>
                    <div id="photo-preview" class="hidden absolute inset-0">
                        <img id="preview-img" class="w-full h-full object-cover">
                        <button id="retake-btn" class="absolute top-4 right-4 bg-black/60 text-white w-10 h-10 flex items-center justify-center rounded-full backdrop-blur-md">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                            </svg>
                        </button>
                    </div>
                </div>
                <p class="text-[10px] text-center text-gray-400 font-medium italic">Posisikan wajah Anda di tengah kotak</p>
            </div>
            ` : ''}

            <!-- Submit Button -->
            <div class="pt-2">
                <button id="submit-btn" disabled class="btn-primary w-full py-5 rounded-[1.25rem] text-white font-extrabold text-lg tracking-tight">
                    Kirim Check-in
                </button>
                <p id="error-msg" class="mt-4 text-xs text-red-500 text-center font-bold empty:hidden"></p>
            </div>
        </div>
        
        <canvas id="canvas"></canvas>

        <footer class="mt-16 text-center space-y-2">
            <p class="text-[11px] text-gray-300 font-bold tracking-widest uppercase">Powered by Hadir.in</p>
            <p class="text-[10px] text-gray-400 font-medium">© 2026 Smart Attendance System</p>
        </footer>
    </div>

    <script>
        const eventId = '${eventId}';
        const requirePhoto = ${requirePhoto === 'true'};
        let latitude = null;
        let longitude = null;
        let photoBlob = null;

        const nameInput = document.getElementById('name');
        const emailInput = document.getElementById('email');
        const submitBtn = document.getElementById('submit-btn');
        const errorMsg = document.getElementById('error-msg');
        const locTitle = document.getElementById('loc-title');
        const locStatus = document.getElementById('loc-status');
        const locIcon = document.getElementById('loc-icon');
        const retryLoc = document.getElementById('retry-loc');

        // --- Geolocation ---
        function getGeolocation() {
            locTitle.innerText = "Mendeteksi Lokasi...";
            locStatus.innerText = "Mohon izinkan akses GPS";
            locIcon.className = "w-12 h-12 bg-white text-[#002766] rounded-2xl shadow-sm flex items-center justify-center shimmer";
            retryLoc.classList.add('hidden');

            if (!navigator.geolocation) {
                updateLocError("Browser tidak mendukung GPS.");
                return;
            }

            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    latitude = pos.coords.latitude;
                    longitude = pos.coords.longitude;
                    locTitle.innerText = "Lokasi Berhasil Didapat";
                    locStatus.innerText = latitude.toFixed(6) + ", " + longitude.toFixed(6);
                    locIcon.className = "w-12 h-12 bg-emerald-50 text-emerald-500 rounded-2xl shadow-sm flex items-center justify-center";
                    validateForm();
                },
                (err) => {
                    let msg = "Gagal mengambil lokasi.";
                    if (err.code === 1) msg = "Akses lokasi ditolak.";
                    updateLocError(msg);
                },
                { enableHighAccuracy: true, timeout: 15000 }
            );
        }

        function updateLocError(msg) {
            locTitle.innerText = "Lokasi Gagal";
            locStatus.innerText = msg;
            locIcon.className = "w-12 h-12 bg-red-50 text-red-500 rounded-2xl shadow-sm flex items-center justify-center";
            retryLoc.classList.remove('hidden');
            validateForm();
        }

        retryLoc.onclick = getGeolocation;
        getGeolocation();

        // --- Camera Logic ---
        if (requirePhoto) {
            const video = document.getElementById('video');
            const canvas = document.getElementById('canvas');
            const captureBtn = document.getElementById('capture-btn');
            const preview = document.getElementById('photo-preview');
            const previewImg = document.getElementById('preview-img');
            const retakeBtn = document.getElementById('retake-btn');
            const shimmerOverlay = document.getElementById('shutter-overlay');

            async function startCamera() {
                try {
                    const stream = await navigator.mediaDevices.getUserMedia({ 
                        video: { facingMode: "user", width: { ideal: 1024 }, height: { ideal: 1024 } }, 
                        audio: false 
                    });
                    video.srcObject = stream;
                } catch (err) {
                    errorMsg.innerText = "Gagal membuka kamera. Pastikan izin diberikan.";
                }
            }

            startCamera();

            captureBtn.onclick = () => {
                shimmerOverlay.classList.add('opacity-80');
                setTimeout(() => shimmerOverlay.classList.remove('opacity-80'), 100);

                canvas.width = video.videoWidth;
                canvas.height = video.videoHeight;
                const ctx = canvas.getContext('2d');
                ctx.translate(canvas.width, 0);
                ctx.scale(-1, 1);
                ctx.drawImage(video, 0, 0);
                
                canvas.toBlob((blob) => {
                    photoBlob = blob;
                    previewImg.src = URL.createObjectURL(blob);
                    preview.classList.remove('hidden');
                    validateForm();
                }, 'image/jpeg', 0.85);
            };

            retakeBtn.onclick = () => {
                photoBlob = null;
                preview.classList.add('hidden');
                validateForm();
            };
        }

        // --- Form Validation ---
        function validateForm() {
            const isNameOk = nameInput.value.trim().length > 0;
            const isLocOk = latitude !== null && longitude !== null;
            const isPhotoOk = !requirePhoto || photoBlob !== null;

            submitBtn.disabled = !(isNameOk && isLocOk && isPhotoOk);
        }

        nameInput.oninput = validateForm;

        // --- Submit Logic ---
        submitBtn.onclick = async () => {
            submitBtn.disabled = true;
            submitBtn.innerText = "Tunggu sebentar...";
            errorMsg.innerText = "";

            const formData = new FormData();
            formData.append('name', nameInput.value.trim());
            formData.append('email', emailInput.value.trim());
            formData.append('latitude', latitude);
            formData.append('longitude', longitude);
            formData.append('requirePhoto', requirePhoto);
            if (photoBlob) {
                formData.append('photo', photoBlob, 'attendance.jpg');
            }

            try {
                const res = await fetch(\`/api/attendance/self-checkin/\${eventId}\`, {
                    method: 'POST',
                    body: formData
                });

                const data = await res.json();
                if (data.status === 'success') {
                    document.getElementById('form-card').classList.add('hidden');
                    document.getElementById('success-card').classList.remove('hidden');
                    document.getElementById('success-message').innerText = data.message;
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                } else {
                    errorMsg.innerText = data.message;
                    submitBtn.disabled = false;
                    submitBtn.innerText = "Kirim Check-in";
                }
            } catch (err) {
                errorMsg.innerText = "Gagal terhubung ke server.";
                submitBtn.disabled = false;
                submitBtn.innerText = "Kirim Check-in";
            }
        };
    </script>
</body>
</html>
        `;

        res.send(html);
    } catch (err) {
        console.error("renderSelfCheckInPage error:", err);
        res.status(500).send('Terjadi kesalahan server.');
    }
};

// ─── Hapus Log Absensi ───
const deleteLog = async (req, res) => {
    try {
        const { logId } = req.params;

        // Cek log
        const log = await prisma.attendanceLog.findUnique({
            where: { id: logId }
        });

        if (!log) {
            return res.status(404).json({
                status: "error",
                message: "Log tidak ditemukan."
            });
        }

        // Cek permission (apakah user adalah organizer atau panitia dari event terkait log ini)
        const event = await prisma.event.findFirst({
            where: {
                id: log.eventId,
                OR: [
                    { organizerId: req.user.id },
                    { committees: { some: { userId: req.user.id } } }
                ]
            }
        });

        if (!event) {
            return res.status(403).json({
                status: "error",
                message: "Anda tidak memiliki akses untuk menghapus log di event ini."
            });
        }

        // Hapus log
        await prisma.attendanceLog.delete({
            where: { id: logId }
        });

        // (Opsional) Mengubah status partisipan menjadi unused jika ini adalah satu-satunya log untuk partisipan. 
        // Untuk amannya, kita set unused jika ingin partisipan bisa scan lagi.
        await prisma.participant.update({
            where: { id: log.participantId },
            data: { status: 'unused' }
        }).catch(() => { });

        return res.status(200).json({
            status: "success",
            message: "Log absen berhasil dihapus."
        });

    } catch (error) {
        console.error("deleteLog error:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat menghapus log."
        });
    }
};

module.exports = {
    scanTicket,
    getAttendanceLogs,
    selfCheckIn,
    renderSelfCheckInPage,
    deleteLog
};

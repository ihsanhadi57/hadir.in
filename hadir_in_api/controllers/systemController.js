const prisma = require('../config/prisma');
const { cloudinary } = require('../config/cloudinary');

const runCleanup = async (req, res) => {
    try {
        const { secret } = req.query;

        // Security check
        if (secret !== process.env.SYSTEM_SECRET) {
            return res.status(401).json({ status: "error", message: "Unauthorized system access." });
        }

        // Cari event yang tanggalnya < hari ini - 3 hari
        // Kita hitung threshold date (3 hari yang lalu)
        const thresholdDate = new Date();
        thresholdDate.setDate(thresholdDate.getDate() - 3);

        const expiredEvents = await prisma.event.findMany({
            where: {
                date: {
                    lt: thresholdDate
                }
            },
            select: { id: true }
        });

        if (expiredEvents.length === 0) {
            return res.status(200).json({ status: "success", message: "Tidak ada event kadaluarsa (H+3) untuk dibersihkan." });
        }

        const deletedIds = expiredEvents.map(e => e.id);
        const results = [];

        for (const eventId of deletedIds) {
            try {
                // 1. Hapus Folder Cloudinary (Banner & Absensi)
                const folders = [
                    `hadirin/events/${eventId}`,
                    `hadirin/attendance/${eventId}`
                ];

                for (const folder of folders) {
                    await cloudinary.api.delete_resources_by_prefix(folder);
                    await cloudinary.api.delete_folder(folder).catch(() => {});
                }

                // 2. Hapus Record Database (Cascade)
                await prisma.event.delete({ where: { id: eventId } });
                results.push(eventId);
            } catch (err) {
                console.error(`Gagal membersihkan event ${eventId}:`, err.message);
            }
        }

        return res.status(200).json({
            status: "success",
            message: `Pembersihan berhasil. ${results.length} event kadaluarsa dihapus.`,
            deletedEventIds: results
        });

    } catch (error) {
        console.error("Error runCleanup:", error);
        return res.status(500).json({ status: "error", message: "Terjadi kesalahan sistem saat pembersihan." });
    }
};

const testSES = async (req, res) => {
    try {
        const { email } = req.query;
        if (!email) {
            return res.status(400).json({ status: "error", message: "Parameter email wajib diisi (contoh: ?email=kamu@gmail.com)." });
        }

        const emailService = require('../services/emailService');
        
        // Buat dummy data
        const participant = { name: "Tester Hadir.in", email: email, ticketId: "TEST-12345" };
        const event = { name: "System Diagnostic Test", contactEmail: "admin@hadirin.space" };
        const dummyBuffer = Buffer.from('Test Ticket Image Content');

        await emailService.sendTicketEmail(participant, event, dummyBuffer);

        return res.status(200).json({
            status: "success",
            message: `Email tes berhasil dikirim ke ${email}. Silakan cek inbox/spam.`
        });
    } catch (error) {
        console.error("SES Diagnostic Error:", error);
        return res.status(500).json({
            status: "error",
            message: "Gagal mengirim email tes.",
            details: error.message
        });
    }
};

module.exports = {
    runCleanup,
    testSES
};

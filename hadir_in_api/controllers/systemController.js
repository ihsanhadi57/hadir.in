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

module.exports = {
    runCleanup
};

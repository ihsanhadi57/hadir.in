const prisma = require('../config/prisma');

const getEventStats = async (req, res) => {
    try {
        const { eventId } = req.params;

        // 1. Verifikasi kepemilikan event
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
                message: "Anda tidak memiliki akses ke data statistik event ini."
            });
        }

        // 2. Ambil statistik angka
        const totalParticipants = await prisma.participant.count({
            where: { eventId }
        });

        const attendedCount = await prisma.participant.count({
            where: { 
                eventId,
                status: 'used'
            }
        });

        const unAttendedCount = totalParticipants - attendedCount;

        // 3. Ambil 5 riwayat kehadiran terakhir
        const recentLogs = await prisma.attendanceLog.findMany({
            where: { eventId },
            include: {
                participant: {
                    select: { name: true, email: true }
                }
            },
            orderBy: { scannedAt: 'desc' },
            take: 5
        });

        return res.status(200).json({
            status: "success",
            data: {
                eventName: event.name,
                stats: {
                    total: totalParticipants,
                    attended: attendedCount,
                    unattended: unAttendedCount,
                    attendanceRate: totalParticipants > 0 
                        ? ((attendedCount / totalParticipants) * 100).toFixed(2) + "%" 
                        : "0%"
                },
                recentScans: recentLogs.map(log => ({
                    id: log.id,
                    name: log.participant.name,
                    email: log.participant.email,
                    scannedAt: log.scannedAt
                }))
            }
        });

    } catch (error) {
        console.error("Error getEventStats:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat memproses data statistik dashboard."
        });
    }
};

module.exports = {
    getEventStats
};

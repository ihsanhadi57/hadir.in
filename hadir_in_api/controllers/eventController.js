const prisma = require('../config/prisma');

const createEvent = async (req, res) => {
    try {
        const { name, description, date, latitude, longitude, contactEmail } = req.body;

        if (!name || !date) {
            return res.status(400).json({
                status: "error",
                message: "Nama event dan tanggal wajib diisi."
            });
        }

        const inviteCode = Math.random().toString(36).substring(2, 8).toUpperCase();

        const newEvent = await prisma.event.create({
            data: {
                name,
                description,
                contactEmail,
                date: new Date(date),
                latitude: latitude ? parseFloat(latitude) : null,
                longitude: longitude ? parseFloat(longitude) : null,
                organizerId: req.user.id,
                inviteCode
            }
        });

        return res.status(201).json({
            status: "success",
            message: "Event berhasil dibuat.",
            data: newEvent
        });
    } catch (error) {
        console.error("Error createEvent:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat membuat event."
        });
    }
};

const getMyEvents = async (req, res) => {
    try {
        const events = await prisma.event.findMany({
            where: {
                OR: [
                    { organizerId: req.user.id },
                    { committees: { some: { userId: req.user.id } } }
                ]
            },
            orderBy: {
                createdAt: 'desc'
            }
        });

        return res.status(200).json({
            status: "success",
            data: events
        });
    } catch (error) {
        console.error("Error getMyEvents:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat mengambil daftar event."
        });
    }
};

const uploadEventImage = async (req, res) => {
    try {
        const { eventId } = req.params;
        
        if (!req.file) {
            return res.status(400).json({ status: "error", message: "File gambar tidak ditemukan." });
        }

        const event = await prisma.event.findFirst({
            where: { id: eventId, organizerId: req.user.id }
        });

        if (!event) {
            return res.status(403).json({ status: "error", message: "Akses ditolak." });
        }

        const updatedEvent = await prisma.event.update({
            where: { id: eventId },
            data: { imageUrl: req.file.path.replace(/\\/g, '/') } // Simpan path dengan slash yang konsisten
        });

        return res.status(200).json({
            status: "success",
            message: "Gambar event berhasil diunggah.",
            data: { imageUrl: updatedEvent.imageUrl }
        });
    } catch (error) {
        console.error("Error uploadEventImage:", error);
        return res.status(500).json({ status: "error", message: "Terjadi kesalahan sistem saat unggah gambar." });
    }
};

const uploadTemplate = async (req, res) => {
    try {
        const { eventId } = req.params;
        
        if (!req.file) {
            return res.status(400).json({ status: "error", message: "File gambar tidak ditemukan." });
        }

        const event = await prisma.event.findFirst({
            where: { id: eventId, organizerId: req.user.id }
        });

        if (!event) {
            return res.status(403).json({ status: "error", message: "Akses ditolak." });
        }

        const updatedEvent = await prisma.event.update({
            where: { id: eventId },
            data: { ticketTemplateUrl: req.file.path }
        });

        return res.status(200).json({
            status: "success",
            message: "Template berhasil diunggah.",
            data: { path: updatedEvent.ticketTemplateUrl }
        });
    } catch (error) {
        console.error("Error uploadTemplate:", error);
        return res.status(500).json({ status: "error", message: "Terjadi kesalahan sistem." });
    }
};

const updateTemplateConfig = async (req, res) => {
    try {
        const { eventId } = req.params;
        const config = req.body; // { nameX, nameY, qrX, qrY, qrSize, nameColor, nameSize } dll

        const event = await prisma.event.findFirst({
            where: { id: eventId, organizerId: req.user.id }
        });

        if (!event) {
            return res.status(403).json({ status: "error", message: "Akses ditolak." });
        }

        const updatedEvent = await prisma.event.update({
            where: { id: eventId },
            data: { ticketConfig: config }
        });

        return res.status(200).json({
            status: "success",
            message: "Konfigurasi template berhasil disimpan.",
            data: updatedEvent.ticketConfig
        });
    } catch (error) {
        console.error("Error updateTemplateConfig:", error);
        return res.status(500).json({ status: "error", message: "Gagal menyimpan konfigurasi." });
    }
};

const getEventTemplate = async (req, res) => {
    try {
        const { eventId } = req.params;

        const event = await prisma.event.findFirst({
            where: { 
                id: eventId, 
                OR: [
                    { organizerId: req.user.id },
                    { committees: { some: { userId: req.user.id } } }
                ]
            },
            select: { ticketTemplateUrl: true, ticketConfig: true }
        });
        
        if (!event) {
            return res.status(403).json({ status: 'error', message: 'Akses ditolak.' });
        }

        return res.status(200).json({
            status: 'success',
            data: {
                // Convert local path (e.g. "uploads/templates/abc") to a public URL
                templateUrl: event.ticketTemplateUrl
                    ? `${process.env.BASE_URL || 'http://localhost:3000'}/${event.ticketTemplateUrl.replace(/\\/g, '/')}`
                    : null,
                config: event.ticketConfig
            }
        });
    } catch (error) {
        console.error('Error getEventTemplate:', error);
        return res.status(500).json({ status: 'error', message: 'Terjadi kesalahan sistem.' });
    }
};

const joinEvent = async (req, res) => {
    try {
        const { code } = req.params;
        
        const event = await prisma.event.findUnique({
            where: { inviteCode: code }
        });

        if (!event) {
            return res.status(404).json({ status: 'error', message: 'Kode undangan tidak valid.' });
        }

        if (event.organizerId === req.user.id) {
            return res.status(400).json({ status: 'error', message: 'Anda adalah pembuat event ini.' });
        }

        const existing = await prisma.eventCommittee.findUnique({
            where: {
                eventId_userId: { eventId: event.id, userId: req.user.id }
            }
        });

        if (existing) {
            return res.status(200).json({ status: 'success', message: 'Anda sudah tergabung sebagai panitia.' });
        }

        await prisma.eventCommittee.create({
            data: {
                eventId: event.id,
                userId: req.user.id,
                role: 'panitia'
            }
        });

        return res.status(200).json({ status: 'success', message: 'Berhasil bergabung sebagai panitia!' });
    } catch (error) {
        console.error('Error joinEvent:', error);
        return res.status(500).json({ status: 'error', message: 'Terjadi kesalahan sistem.' });
    }
};

// ─── Update Event ───
const updateEvent = async (req, res) => {
    try {
        const { eventId } = req.params;
        const { name, description, date, contactEmail, latitude, longitude } = req.body;

        const event = await prisma.event.findFirst({
            where: { id: eventId, organizerId: req.user.id }
        });

        if (!event) {
            return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses ke event ini." });
        }

        const updated = await prisma.event.update({
            where: { id: eventId },
            data: {
                ...(name && { name }),
                ...(description !== undefined && { description }),
                ...(date && { date: new Date(date) }),
                ...(contactEmail !== undefined && { contactEmail: contactEmail || null }),
                ...(latitude !== undefined && { latitude: latitude ? parseFloat(latitude) : null }),
                ...(longitude !== undefined && { longitude: longitude ? parseFloat(longitude) : null }),
            }
        });

        return res.status(200).json({
            status: "success",
            message: "Event berhasil diperbarui.",
            data: updated
        });
    } catch (error) {
        console.error("Error updateEvent:", error);
        return res.status(500).json({ status: "error", message: "Gagal memperbarui event." });
    }
};

// ─── Hapus Event ───
const deleteEvent = async (req, res) => {
    try {
        const { eventId } = req.params;

        const event = await prisma.event.findFirst({
            where: { id: eventId, organizerId: req.user.id }
        });

        if (!event) {
            return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses ke event ini." });
        }

        await prisma.event.delete({ where: { id: eventId } });

        return res.status(200).json({
            status: "success",
            message: "Event berhasil dihapus beserta seluruh datanya."
        });
    } catch (error) {
        console.error("Error deleteEvent:", error);
        return res.status(500).json({ status: "error", message: "Gagal menghapus event." });
    }
};

module.exports = {
    createEvent,
    getMyEvents,
    updateEvent,
    deleteEvent,
    uploadTemplate,
    uploadEventImage,
    updateTemplateConfig,
    getEventTemplate,
    joinEvent
};

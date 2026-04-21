const prisma = require('../config/prisma');
const fs = require('fs');
const csv = require('csv-parser');
const nodemailer = require('nodemailer');
const QRCode = require('qrcode');
const { Jimp } = require('jimp');
const sharp = require('sharp');
const jwt = require('jsonwebtoken');
const emailService = require('../services/emailService');
const { isValidEmailFormat, fixEmailTypo, hasValidMxRecord } = require('../utils/emailValidator');

const registerManual = async (req, res) => {
    try {
        const { eventId, name, email, noTelp } = req.body;

        if (!eventId || !name || !email) {
            return res.status(400).json({
                status: "error",
                message: "Event ID, nama, dan email wajib diisi."
            });
        }

        // Cek apakah event milik organizer ini
        const event = await prisma.event.findFirst({
            where: {
                id: eventId,
                organizerId: req.user.id
            }
        });

        if (!event) {
            return res.status(403).json({
                status: "error",
                message: "Anda tidak memiliki akses ke event ini."
            });
        }

        let finalEmail = fixEmailTypo(email);
        if (!isValidEmailFormat(finalEmail)) {
            return res.status(400).json({ status: "error", message: "Format email tidak valid." });
        }

        const participant = await prisma.participant.create({
            data: { eventId, name, email: finalEmail, noTelp }
        });

        return res.status(201).json({
            status: "success",
            message: "Peserta berhasil terdaftar.",
            data: participant
        });
    } catch (error) {
        console.error("Error registerManual:", error);
        if (error.code === 'P2002') {
            return res.status(400).json({
                status: "error",
                message: "Email ini sudah terdaftar di event yang sama."
            });
        }
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat mendaftarkan peserta."
        });
    }
};

const registerBulk = async (req, res) => {
    try {
        const { eventId } = req.body;

        if (!eventId) {
            return res.status(400).json({
                status: "error",
                message: "Event ID wajib disertakan."
            });
        }

        if (!req.file) {
            return res.status(400).json({
                status: "error",
                message: "File CSV tidak ditemukan."
            });
        }

        // Cek kepemilikan event
        const event = await prisma.event.findFirst({
            where: {
                id: eventId,
                organizerId: req.user.id
            }
        });

        if (!event) {
            // Hapus file sementara jika bukan pemilik
            fs.unlinkSync(req.file.path);
            return res.status(403).json({
                status: "error",
                message: "Anda tidak memiliki akses ke event ini."
            });
        }

        const results = [];

        // Baca file, bersihkan BOM dan baris "sep=," agar csv-parser tidak bingung
        let rawContent = fs.readFileSync(req.file.path, 'utf-8');
        // Hapus BOM jika ada
        rawContent = rawContent.replace(/^\uFEFF/, '');
        // Hapus baris sep=, jika ada (hint khusus Excel)
        rawContent = rawContent.replace(/^sep=.*[\r\n]+/i, '');
        // Tulis ulang file yang sudah bersih
        fs.writeFileSync(req.file.path, rawContent, 'utf-8');

        fs.createReadStream(req.file.path)
            .pipe(csv())
            .on('data', (data) => {
                if (data.name && data.email) {
                    let cleanedEmail = data.email.trim();
                    cleanedEmail = fixEmailTypo(cleanedEmail);
                    if (isValidEmailFormat(cleanedEmail)) {
                        results.push({
                            eventId,
                            name: data.name.trim(),
                            email: cleanedEmail,
                            noTelp: data.noTelp ? data.noTelp.trim() : null
                        });
                    }
                }
            })
            .on('end', async () => {
                try {
                    if (results.length === 0) {
                        fs.unlinkSync(req.file.path);
                        return res.status(400).json({
                            status: "error",
                            message: "File CSV tidak memiliki data peserta yang valid. Pastikan kolom 'name' dan 'email' terisi."
                        });
                    }

                    // Gunakan createMany untuk efisiensi (skipDuplicates: true agar tidak error jika ada email sama)
                    const count = await prisma.participant.createMany({
                        data: results,
                        skipDuplicates: true
                    });

                    // Hapus file setelah selesai
                    fs.unlinkSync(req.file.path);

                    const skipped = results.length - count.count;
                    let message = `${count.count} peserta baru berhasil ditambahkan.`;
                    if (skipped > 0) {
                        message += ` ${skipped} data dilewati karena sudah terdaftar.`;
                    }

                    return res.status(201).json({
                        status: "success",
                        message,
                        data: { inserted: count.count, skipped, total: results.length }
                    });
                } catch (dbError) {
                    console.error("Error DB Bulk:", dbError);
                    fs.unlinkSync(req.file.path);
                    return res.status(500).json({
                        status: "error",
                        message: "Terjadi kesalahan saat menyimpan data peserta."
                    });
                }
            });

    } catch (error) {
        console.error("Error registerBulk:", error);
        if (req.file) fs.unlinkSync(req.file.path);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat mengolah file CSV."
        });
    }
};

const getParticipants = async (req, res) => {
    try {
        const { eventId } = req.params;

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
                message: "Anda tidak memiliki akses ke peserta event ini."
            });
        }

        const participants = await prisma.participant.findMany({
            where: { eventId },
            orderBy: { createdAt: 'desc' }
        });

        return res.status(200).json({
            status: "success",
            data: participants
        });
    } catch (error) {
        console.error("Error getParticipants:", error);
        return res.status(500).json({
            status: "error",
            message: "Terjadi kesalahan saat mengambil daftar peserta."
        });
    }
};

// ─── Update Peserta ───
const updateParticipant = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, email, noTelp } = req.body;

        const participant = await prisma.participant.findUnique({
            where: { id },
            include: { event: true }
        });

        if (!participant) {
            return res.status(404).json({ status: "error", message: "Peserta tidak ditemukan." });
        }

        if (participant.event.organizerId !== req.user.id) {
            return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses." });
        }

        let finalEmail = email;
        if (email) {
            finalEmail = fixEmailTypo(email);
            if (!isValidEmailFormat(finalEmail)) {
                return res.status(400).json({ status: "error", message: "Format email tidak valid." });
            }
        }

        const updated = await prisma.participant.update({
            where: { id },
            data: {
                ...(name && { name }),
                ...(email && { email: finalEmail }),
                ...(noTelp !== undefined && { noTelp: noTelp || null }),
            }
        });

        return res.status(200).json({
            status: "success",
            message: "Data peserta berhasil diperbarui.",
            data: updated
        });
    } catch (error) {
        console.error("Error updateParticipant:", error);
        if (error.code === 'P2002') {
            return res.status(400).json({ status: "error", message: "Email ini sudah terdaftar di event yang sama." });
        }
        return res.status(500).json({ status: "error", message: "Gagal memperbarui data peserta." });
    }
};

// ─── Hapus Peserta ───
const deleteParticipant = async (req, res) => {
    try {
        const { id } = req.params;

        const participant = await prisma.participant.findUnique({
            where: { id },
            include: { event: true }
        });

        if (!participant) {
            return res.status(404).json({ status: "error", message: "Peserta tidak ditemukan." });
        }

        if (participant.event.organizerId !== req.user.id) {
            return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses." });
        }

        await prisma.participant.delete({ where: { id } });

        return res.status(200).json({
            status: "success",
            message: "Peserta berhasil dihapus."
        });
    } catch (error) {
        console.error("Error deleteParticipant:", error);
        return res.status(500).json({ status: "error", message: "Gagal menghapus peserta." });
    }
};

// ─── Kirim Tiket ke 1 Peserta ───
const sendTicket = async (req, res) => {
    try {
        const { id } = req.params;

        const participant = await prisma.participant.findUnique({
            where: { id },
            include: { event: true }
        });

        if (!participant) {
            return res.status(404).json({ status: "error", message: "Peserta tidak ditemukan." });
        }

        if (participant.event.organizerId !== req.user.id) {
            return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses." });
        }

        const event = participant.event;
        const p = participant;

        if (p.unsubscribed) {
            return res.status(400).json({ status: "error", message: "Peserta ini telah memilih berhenti berlangganan (Unsubscribed)." });
        }

        const isValidMx = await hasValidMxRecord(p.email);
        if (!isValidMx) {
            return res.status(400).json({ status: "error", message: "Domain email tujuan tidak valid atau tidak memiliki mail server aktif (Invalid MX Record)." });
        }

        res.status(200).json({ status: "success", message: `Tiket sedang dikirim ke ${p.email}` });

        const qrBuffer = await QRCode.toBuffer(p.ticketId, {
            errorCorrectionLevel: 'H', margin: 2,
            width: event.ticketConfig?.qrSize || 300,
        });

        let finalImageBuffer = qrBuffer;

        if (event.ticketTemplateUrl && event.ticketConfig) {
            try {
                const cfg = event.ticketConfig;
                const qrSize = cfg.qrSize || 300;
                const qrResized = await sharp(qrBuffer).resize(qrSize, qrSize).png().toBuffer();
                const composites = [{ input: qrResized, left: Math.round(cfg.qrX || 0), top: Math.round(cfg.qrY || 0) }];

                if (cfg.nameX !== undefined && cfg.nameY !== undefined) {
                    const fontSize = cfg.nameSize || 48;
                    const color = cfg.nameColor || 'white';
                    const displayName = p.name.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                    const svgText = Buffer.from(
                        `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="${fontSize + 20}">`
                        + `<text x="0" y="${fontSize}" font-family="Arial, Helvetica, sans-serif" font-size="${fontSize}" fill="${color}" font-weight="bold">${displayName}</text>`
                        + `</svg>`
                    );
                    composites.push({ input: svgText, left: Math.round(cfg.nameX), top: Math.round(cfg.nameY) });
                }

                finalImageBuffer = await sharp(event.ticketTemplateUrl).composite(composites).png().toBuffer();
            } catch (err) {
                console.error('Gagal composite untuk', p.email, err);
            }
        }

        // Buat token unsubscribe
        const unsubToken = jwt.sign({ participantId: p.id }, process.env.JWT_SECRET || 'fallback-secret', { expiresIn: '30d' });
        const unsubscribeUrl = `${process.env.BASE_URL}/api/participants/unsubscribe?token=${unsubToken}`;

        // Using AWS SES Service
        await emailService.sendTicketEmail(p, event, finalImageBuffer, unsubscribeUrl);
    } catch (error) {
        console.error("Error sendTicket:", error);
    }
};

const blastTickets = async (req, res) => {
    try {
        const { eventId } = req.params;
        const { startIndex, endIndex } = req.body;

        const event = await prisma.event.findFirst({
            where: { id: eventId, organizerId: req.user.id },
            include: {
                participants: {
                    orderBy: { createdAt: 'desc' }
                }
            }
        });

        if (!event) {
            return res.status(403).json({ status: "error", message: "Akses ditolak." });
        }

        if (event.participants.length === 0) {
            return res.status(400).json({ status: "error", message: "Event ini belum memiliki peserta." });
        }

        // ─── Cek Quota Organizer ───
        const organizer = await prisma.user.findUnique({ where: { id: req.user.id } });
        if (!organizer) {
            return res.status(404).json({ status: "error", message: "Organizer tidak ditemukan." });
        }

        // ─── Filter Rentang ───
        let targetParticipants = event.participants;
        if (startIndex !== undefined && endIndex !== undefined) {
            const startIdx = Math.max(0, parseInt(startIndex) - 1);
            const endIdx = Math.min(event.participants.length, parseInt(endIndex));
            targetParticipants = event.participants.slice(startIdx, endIdx);

            if (targetParticipants.length === 0) {
                return res.status(400).json({ status: "error", message: "Rentang tidak valid atau tidak ada peserta di rentang tersebut." });
            }
        }

        const needed = targetParticipants.length;
        if (organizer.emailQuota < needed) {
            return res.status(429).json({
                status: "error",
                message: `Quota email tidak mencukupi. Kamu butuh ${needed} email, tapi sisa quota kamu hanya ${organizer.emailQuota}. Tambah quota sekarang di halaman Akun!`,
                data: { needed, remaining: organizer.emailQuota }
            });
        }

        res.status(200).json({
            status: "success",
            message: `Proses pengiriman tiket sedang berjalan di latar belakang dan membutuhkan waktu beberapa saat.`
        });

        // ─── Kurangi Quota & Tambah Counter (Optimistic, sebelum send) ───
        await prisma.user.update({
            where: { id: req.user.id },
            data: {
                emailQuota: { decrement: needed },
                totalEmailsSent: { increment: needed },
            }
        });

        // Loop over target participants and send asynchronously via AWS SES
        for (const p of targetParticipants) {
            const qrBuffer = await QRCode.toBuffer(p.ticketId, {
                errorCorrectionLevel: 'H',
                margin: 2,
                width: event.ticketConfig?.qrSize || 300,
            });

            let finalImageBuffer = qrBuffer;

            if (event.ticketTemplateUrl && event.ticketConfig) {
                try {
                    const cfg = event.ticketConfig;
                    const qrSize = cfg.qrSize || 300;

                    const qrResized = await sharp(qrBuffer).resize(qrSize, qrSize).png().toBuffer();
                    const composites = [{ input: qrResized, left: Math.round(cfg.qrX || 0), top: Math.round(cfg.qrY || 0) }];

                    if (cfg.nameX !== undefined && cfg.nameY !== undefined) {
                        const fontSize = cfg.nameSize || 48;
                        const color = cfg.nameColor || 'white';
                        const displayName = p.name.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                        const svgText = Buffer.from(
                            `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="${fontSize + 20}">`
                            + `<text x="0" y="${fontSize}" font-family="Arial, Helvetica, sans-serif" font-size="${fontSize}" fill="${color}" font-weight="bold">${displayName}</text>`
                            + `</svg>`
                        );
                        composites.push({ input: svgText, left: Math.round(cfg.nameX), top: Math.round(cfg.nameY) });
                    }

                    finalImageBuffer = await sharp(event.ticketTemplateUrl).composite(composites).png().toBuffer();
                } catch (err) {
                    console.error('Gagal composite sharp untuk', p.email, err);
                }
            }

            try {
                // Buat token unsubscribe
                    const unsubToken = jwt.sign({ participantId: p.id }, process.env.JWT_SECRET || 'fallback-secret', { expiresIn: '30d' });
                    const unsubscribeUrl = `${process.env.BASE_URL}/api/participants/unsubscribe?token=${unsubToken}`;

                    await emailService.sendTicketEmail(p, event, finalImageBuffer, unsubscribeUrl);
                } catch (err) {
                    console.error("AWS SES Error untuk", p.email, err);
                }
            }

            console.log(`Proses blast tiket selesai untuk event ${event.name}`);

        } catch (error) {
            console.error("Error blastTickets:", error);
        }
    };

    // ─── Unsubscribe Handler ───
    const unsubscribe = async (req, res) => {
        try {
            const { token } = req.query;
            if (!token) return res.status(400).send("Token tidak valid.");

            const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback-secret');
            const participant = await prisma.participant.update({
                where: { id: decoded.participantId },
                data: { unsubscribed: true },
                include: { event: true }
            });

            // Tampilkan halaman sukses sederhana
            res.send(`
            <div style="font-family: sans-serif; text-align: center; margin-top: 50px;">
                <h2 style="color: #4B5563;">Berhasil Berhenti Berlangganan</h2>
                <p>Kamu tidak akan lagi menerima email blast dari event <strong>${participant.event.name}</strong>.</p>
            </div>
        `);
        } catch (error) {
            res.status(400).send("Token kadaluarsa atau tidak valid.");
        }
    };

    // Endpoint untuk download template CSV

    const downloadTemplate = async (req, res) => {
        try {
            // BOM + sep hint agar Excel otomatis parsing kolom dengan benar
            const BOM = '\uFEFF';
            const sepHint = 'sep=,\r\n';
            const csvContent = [
                'name,email,noTelp',
                'Budi Santoso,budi@email.com,081234567890',
                'Siti Aminah,siti@email.com,082345678901',
                'Andi Pratama,andi@email.com,',
            ].join('\r\n');

            res.setHeader('Content-Type', 'text/csv; charset=utf-8');
            res.setHeader('Content-Disposition', 'attachment; filename="template_peserta_hadir_in.csv"');
            return res.status(200).send(BOM + sepHint + csvContent);
        } catch (error) {
            console.error("Error downloadTemplate:", error);
            return res.status(500).json({ status: "error", message: "Gagal membuat template." });
        }
    };

    module.exports = {
        registerManual,
        registerBulk,
        getParticipants,
        updateParticipant,
        deleteParticipant,
        sendTicket,
        blastTickets,
        downloadTemplate,
        unsubscribe
    };

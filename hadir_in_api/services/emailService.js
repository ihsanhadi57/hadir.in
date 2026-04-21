const { SESv2Client, SendEmailCommand } = require("@aws-sdk/client-sesv2");
const nodemailer = require("nodemailer");

// ─── AWS SESv2 Client ───
const sesClient = new SESv2Client({
    region: process.env.AWS_REGION || "ap-southeast-2",
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
});

// ─── Single Nodemailer Transporter via AWS SES ───
const transporter = nodemailer.createTransport({
    SES: { sesClient, SendEmailCommand },
});

console.log(`[Email Service] Provider: AWS SES (${process.env.AWS_REGION || "ap-southeast-2"})`);

/**
 * sendTicketEmail
 * @param {Object} participant - Data peserta (name, email, ticketId)
 * @param {Object} event       - Data event (name, contactEmail, dll)
 * @param {Buffer} ticketBuffer - Buffer gambar tiket/QR yang sudah di-generate
 * @param {String} unsubscribeUrl - (opsional) URL berhenti berlangganan
 */
const sendTicketEmail = async (participant, event, ticketBuffer, unsubscribeUrl = null) => {
    const fromEmail = process.env.AWS_SES_FROM_EMAIL;
    const fromName  = `${event.name} via Hadir.in`;

    const unsubscribeHtml = unsubscribeUrl
        ? `<div style="margin-top:24px;padding-top:20px;border-top:1px solid #E5E7EB;font-size:11px;color:#9CA3AF;text-align:center;">
               <p>Kamu menerima email ini karena terdaftar di event <strong>${event.name}</strong>.</p>
               <a href="${unsubscribeUrl}" style="color:#6B7280;text-decoration:underline;">Berhenti terima email blast dari event ini</a>
           </div>`
        : `<div style="margin-top:24px;padding-top:20px;border-top:1px solid #E5E7EB;font-size:11px;color:#9CA3AF;text-align:center;">
               <p>Email ini dikirim secara otomatis oleh Hadir.in.</p>
           </div>`;

    const mailOptions = {
        from: `"${fromName}" <${fromEmail}>`,
        replyTo: event.contactEmail || fromEmail,
        to: participant.email,
        subject: `E-Ticket Resmi: ${event.name}`,
        html: `
            <div style="font-family:'Helvetica Neue',Arial,sans-serif;max-width:600px;margin:auto;padding:20px;border:1px solid #E5E7EB;border-radius:16px;background-color:#ffffff;">
                <div style="text-align:center;border-bottom:1px solid #E5E7EB;padding-bottom:20px;">
                    <h1 style="color:#004AC6;margin:0;font-size:24px;">Hadir.in E-Ticket</h1>
                    <p style="color:#6B7280;margin-top:4px;font-size:14px;">The Digital Concierge</p>
                </div>
                <div style="padding:20px 0;text-align:center;">
                    <h2 style="color:#111827;margin-bottom:8px;">Halo, ${participant.name}!</h2>
                    <p style="color:#4B5563;line-height:1.5;margin-bottom:24px;">
                        Berikut adalah E-Ticket Anda untuk acara <strong>${event.name}</strong>.
                    </p>
                    <div style="margin:0 auto;padding:16px;background-color:#EEF2FF;border-radius:12px;max-width:400px;">
                        <p style="margin:0 0 4px 0;font-size:14px;font-weight:bold;color:#2563EB;">📎 Tiket Anda ada di Lampiran</p>
                        <p style="margin:0;font-size:12px;color:#4B5563;">Unduh file <strong>E-Ticket.png</strong> yang terlampir, simpan, dan tunjukkan kepada panitia saat kedatangan.</p>
                    </div>
                    <div style="margin-top:24px;padding:12px;background-color:#F9FAFB;border-radius:8px;display:inline-block;">
                        <p style="margin:0;font-size:12px;color:#6B7280;">TICKET ID</p>
                        <p style="margin:4px 0 0 0;font-family:monospace;font-size:16px;font-weight:bold;color:#111827;">${participant.ticketId}</p>
                    </div>
                </div>
                ${unsubscribeHtml}
            </div>
        `,
        attachments: [
            {
                filename: 'E-Ticket.png',
                content: ticketBuffer,
                contentType: 'image/png',
            }
        ]
    };

    try {
        const result = await transporter.sendMail(mailOptions);
        console.log(`[SES] Sent → ${participant.email} | MessageId: ${result.messageId}`);
        return result;
    } catch (error) {
        console.error(`[SES ERROR] Failed → ${participant.email}:`, error.message);
        throw error;
    }
};

/**
 * sendOTPEmail
 * @param {String} email - Email tujuan
 * @param {String} otp - Kode 6 angka
 */
const sendOTPEmail = async (email, otp) => {
    const fromEmail = process.env.AWS_SES_FROM_EMAIL;
    const fromName = "Hadir.in Security";

    const mailOptions = {
        from: `"${fromName}" <${fromEmail}>`,
        to: email,
        subject: `Kode Verifikasi Hadir.in: ${otp}`,
        html: `
            <div style="font-family:'Helvetica Neue',Arial,sans-serif;max-width:500px;margin:auto;padding:20px;border:1px solid #E5E7EB;border-radius:16px;">
                <div style="text-align:center;margin-bottom:24px;">
                    <h1 style="color:#2563EB;margin:0;font-size:24px;">Verifikasi Akun</h1>
                </div>
                <p style="color:#4B5563;font-size:16px;line-height:1.5;">
                    Halo! Terima kasih telah bergabung dengan <strong>Hadir.in</strong>. 
                    Gunakan kode OTP di bawah ini untuk memverifikasi akun Anda dan mendapatkan kuota gratis:
                </p>
                <div style="margin:30px 0;padding:20px;background-color:#F3F4F6;border-radius:12px;text-align:center;">
                    <span style="font-family:monospace;font-size:32px;font-weight:bold;letter-spacing:8px;color:#111827;">${otp}</span>
                </div>
                <p style="color:#9CA3AF;font-size:12px;text-align:center;">
                    Kode ini akan kadaluarsa dalam 10 menit. Jangan bagikan kode ini kepada siapapun.
                </p>
            </div>
        `,
    };

    try {
        const result = await transporter.sendMail(mailOptions);
        console.log(`[OTP] Sent → ${email} | MessageId: ${result.messageId}`);
        return result;
    } catch (error) {
        console.error(`[OTP ERROR] Failed → ${email}:`, error.message);
        throw error;
    }
};

module.exports = {
    sendTicketEmail,
    sendOTPEmail
};

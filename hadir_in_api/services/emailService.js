const axios = require("axios");
const qs = require("qs");
const { cloudinary } = require("../config/cloudinary");

// ─── Mailketing Config ───
const MAILKETING_API_URL = "https://api.mailketing.co.id/api/v1/send";
const API_TOKEN = process.env.MAILKETING_API_TOKEN;
const FROM_EMAIL = process.env.MAILKETING_FROM_EMAIL; // tickets@hadirin.space

console.log(`[Email Service] Provider: Mailketing (${FROM_EMAIL})`);

/**
 * Helper internal kirim email via Mailketing API (multipart/form-data)
 */
const _send = async ({ fromName, to, subject, html, attachmentUrl = null }) => {
    // Mailketing API strictness: Strip newlines, tabs, and excess whitespace from HTML
    const cleanHtml = html.replace(/\r?\n|\r|\t/g, '').replace(/\s{2,}/g, ' ').trim();

    const data = {
        api_token: API_TOKEN,
        from_name: fromName,
        from_email: FROM_EMAIL,
        recipient: to,
        subject: subject,
        content: cleanHtml,
    };

    if (attachmentUrl) {
        data.attach1 = attachmentUrl;
    }

    const response = await axios.post(MAILKETING_API_URL, qs.stringify(data), {
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
    });

    if (response.data?.status === "failed") {
        throw new Error(`Mailketing error: ${response.data?.response}`);
    }

    return response.data;
};

/**
 * sendTicketEmail
 * @param {Object} participant    - Data peserta (name, email, ticketId)
 * @param {Object} event          - Data event (name, contactEmail, dll)
 * @param {Buffer} ticketBuffer   - Tidak dipakai langsung, perlu upload ke Cloudinary dulu
 * @param {String} unsubscribeUrl - (opsional) URL berhenti berlangganan
 * @param {String} ticketUrl      - URL publik file tiket (dari Cloudinary) untuk attachment
 */
const sendTicketEmail = async (participant, event, ticketBuffer, unsubscribeUrl = null) => {
    const fromName = `${event.name} via Hadir.in`;

    // Karena Anda tidak ingin menggunakan Cloudinary dan Mailketing tidak mendukung raw Buffer attachment,
    // kita ubah Buffer tiket menjadi string Base64 agar bisa langsung tertanam di dalam HTML email.
    let base64ImageHtml = "";
    if (ticketBuffer) {
        const base64Str = ticketBuffer.toString("base64");
        const dataUri = `data:image/png;base64,${base64Str}`;
        base64ImageHtml = `
            <div style="margin:20px auto; text-align:center;">
                <img src="${dataUri}" alt="E-Ticket ${event.name}" style="max-width:100%; border-radius:12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);" />
            </div>
            <div style="margin:0 auto;padding:16px;background-color:#EEF2FF;border-radius:12px;max-width:400px;">
                <p style="margin:0 0 4px 0;font-size:14px;font-weight:bold;color:#2563EB;">📎 Simpan Tiket Anda</p>
                <p style="margin:0;font-size:12px;color:#4B5563;">Tekan dan tahan (atau klik kanan) gambar tiket di atas lalu pilih <strong>"Simpan Gambar"</strong>, dan tunjukkan kepada panitia saat kedatangan.</p>
            </div>
        `;
    }

    const unsubscribeHtml = unsubscribeUrl
        ? `<div style="margin-top:24px;padding-top:20px;border-top:1px solid #E5E7EB;font-size:11px;color:#9CA3AF;text-align:center;">
               <p>Kamu menerima email ini karena terdaftar di event <strong>${event.name}</strong>.</p>
               <a href="${unsubscribeUrl}" style="color:#6B7280;text-decoration:underline;">Berhenti terima email blast dari event ini</a>
           </div>`
        : `<div style="margin-top:24px;padding-top:20px;border-top:1px solid #E5E7EB;font-size:11px;color:#9CA3AF;text-align:center;">
               <p>Email ini dikirim secara otomatis oleh Hadir.in.</p>
           </div>`;

    const html = `
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
                ${base64ImageHtml}
                <div style="margin-top:24px;padding:12px;background-color:#F9FAFB;border-radius:8px;display:inline-block;">
                    <p style="margin:0;font-size:12px;color:#6B7280;">TICKET ID</p>
                    <p style="margin:4px 0 0 0;font-family:monospace;font-size:16px;font-weight:bold;color:#111827;">${participant.ticketId}</p>
                </div>
            </div>
            ${unsubscribeHtml}
        </div>
    `;

    try {
        const result = await _send({
            fromName,
            to: participant.email,
            subject: `E-Ticket Resmi: ${event.name}`,
            html
        });

        console.log(`[Mailketing] Ticket sent → ${participant.email}`);
        return result;
    } catch (error) {
        console.error(`[Mailketing ERROR] Ticket failed → ${participant.email}:`, error.message);
        throw error;
    }
};

/**
 * sendOTPEmail
 * @param {String} email - Email tujuan
 * @param {String} otp   - Kode 6 angka
 */
const sendOTPEmail = async (email, otp) => {
    const html = `
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
    `;

    try {
        const result = await _send({
            fromName: "Hadir.in Security",
            to: email,
            subject: `Kode Verifikasi Hadir.in: ${otp}`,
            html,
        });

        console.log(`[Mailketing] OTP sent → ${email}`);
        return result;
    } catch (error) {
        console.error(`[Mailketing ERROR] OTP failed → ${email}:`, error.message);
        throw error;
    }
};

module.exports = {
    sendTicketEmail,
    sendOTPEmail,
};
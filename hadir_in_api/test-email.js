require('dotenv').config();
const { sendOTPEmail } = require('./services/emailService');

const testOTP = async () => {
    console.log('🔄 Testing kirim OTP...');
    try {
        await sendOTPEmail('ihsanulhadialghifari@gmail.com', '123422');
        console.log('✅ OTP berhasil dikirim! Cek inbox kamu.');
    } catch (error) {
        console.error('❌ Gagal:', error.message);
    }
};

testOTP();
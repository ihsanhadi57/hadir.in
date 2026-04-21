const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

// Storage untuk Banner Event & Template Designer
const eventStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: async (req, file) => {
    const { eventId } = req.params;
    return {
      folder: `hadirin/events/${eventId || 'misc'}`,
      allowed_formats: ['jpg', 'png', 'jpeg'],
      transformation: [{ width: 1200, crop: 'limit' }]
    };
  }
});

// Storage untuk Foto Absensi (Attendance)
const attendanceStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: async (req, file) => {
    const { eventId } = req.params;
    return {
      folder: `hadirin/attendance/${eventId || 'misc'}`,
      allowed_formats: ['jpg', 'png', 'jpeg'],
      transformation: [{ width: 800, crop: 'limit' }]
    };
  }
});

module.exports = {
  cloudinary,
  eventStorage,
  attendanceStorage
};

const jwt = require('jsonwebtoken');

// ─── Validasi JWT_SECRET saat startup ───
if (!process.env.JWT_SECRET) {
    throw new Error('[AUTH MIDDLEWARE] FATAL: JWT_SECRET environment variable is not set. Server cannot start safely.');
}

const authMiddleware = (req, res, next) => {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
            status: "error",
            message: "Akses ditolak. Token tidak ditemukan."
        });
    }

    const token = authHeader.split(' ')[1];

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        return res.status(401).json({
            status: "error",
            message: "Token tidak valid atau sudah kadaluarsa."
        });
    }
};

module.exports = authMiddleware;


const jwt = require('jsonwebtoken');

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
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'rahasia_super_aman_jwt_123');
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

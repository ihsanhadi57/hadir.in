const prisma = require('./config/prisma');

console.log("Prisma Client Properties:");
const keys = Object.keys(prisma).filter(k => !k.startsWith('_'));
console.log(keys);

process.exit(0);

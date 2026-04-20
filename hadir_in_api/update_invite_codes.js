require('dotenv').config();
const prisma = require('./config/prisma');

async function main() {
    const events = await prisma.event.findMany({
        where: {
            inviteCode: null
        }
    });

    for (const event of events) {
        const inviteCode = Math.random().toString(36).substring(2, 8).toUpperCase();
        await prisma.event.update({
            where: { id: event.id },
            data: { inviteCode }
        });
        console.log(`Updated event ${event.name} with inviteCode: ${inviteCode}`);
    }
    console.log("All done!");
}

main()
    .catch(e => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });

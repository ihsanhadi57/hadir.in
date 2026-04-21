const dns = require('dns');
const { promisify } = require('util');

const resolveMx = promisify(dns.resolveMx);

/**
 * Validates email format using regex.
 */
function isValidEmailFormat(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(String(email).toLowerCase());
}

/**
 * Common typos in generic domains
 */
const _commonTypos = {
    'gmai.com': 'gmail.com',
    'gmil.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.co': 'gmail.com',
    'yaho.com': 'yahoo.com',
    'yahoo.co': 'yahoo.com',
    'hotmai.com': 'hotmail.com'
};

/**
 * Fixes common typos in email domains.
 */
function fixEmailTypo(email) {
    if (!email || !email.includes('@')) return email;
    const parts = email.split('@');
    let domain = parts[1].toLowerCase();
    
    if (_commonTypos[domain]) {
        domain = _commonTypos[domain];
    }
    return `${parts[0]}@${domain}`;
}

/**
 * Checks if the email's domain has valid MX records.
 * - Returns true  → domain has MX records (valid)
 * - Returns false → domain definitively has NO MX records (e.g. ENOTFOUND, ENODATA)
 * - Returns true  → DNS error / timeout (fail-open: don't block valid domains with slow DNS)
 */
async function hasValidMxRecord(email) {
    if (!email || !email.includes('@')) return false;
    const domain = email.split('@')[1].toLowerCase();

    // Langsung loloskan domain-domain populer tanpa perlu DNS lookup
    const _knownValidDomains = new Set([
        'gmail.com', 'yahoo.com', 'yahoo.co.id', 'hotmail.com',
        'outlook.com', 'live.com', 'icloud.com', 'me.com',
        'proton.me', 'protonmail.com', 'yandex.com',
        'hadir.in'
    ]);
    if (_knownValidDomains.has(domain)) return true;

    return new Promise((resolve) => {
        // Timeout 5 detik — jika DNS lambat, anggap valid (fail-open)
        const timer = setTimeout(() => {
            console.warn(`[MX Check] Timeout untuk domain: ${domain}, dianggap valid.`);
            resolve(true);
        }, 5000);

        dns.resolveMx(domain, (err, records) => {
            clearTimeout(timer);
            if (err) {
                // ENOTFOUND = domain tidak ada sama sekali → INVALID
                // ENODATA   = domain ada tapi tidak punya MX → INVALID
                // Lainnya (ETIMEOUT, SERVFAIL, dll.) → Fail-open, anggap VALID
                if (err.code === 'ENOTFOUND' || err.code === 'ENODATA') {
                    console.warn(`[MX Check] Domain tidak valid: ${domain} (${err.code})`);
                    resolve(false);
                } else {
                    console.warn(`[MX Check] DNS error untuk ${domain}: ${err.code}, dianggap valid.`);
                    resolve(true);
                }
            } else {
                resolve(records && records.length > 0);
            }
        });
    });
}

module.exports = {
    isValidEmailFormat,
    fixEmailTypo,
    hasValidMxRecord
};

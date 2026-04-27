/* ══════════════════════════════════════════════════════════════════
   Hadir.in Web Dashboard — app.js
   Full SPA: Auth (Login/Register/Google/OTP) + Dashboard Views
   + Midtrans Snap Integration
   ══════════════════════════════════════════════════════════════════ */

const API = window.location.origin;
const GOOGLE_CLIENT_ID = '115014454509-3411ek97bibeg3io0dq15ai5s0tgtll4.apps.googleusercontent.com';

// ── STATE ──────────────────────────────────────────────
let currentUser = null;
let authToken = localStorage.getItem('hadirin_token');
let selectedPackage = null;
let currentView = 'dashboard';

const PACKAGES = [
    { id: 500,  quota: 500,  amount: 5500,  label: '500 Email',  sub: 'Rp 11/email',        color: 'green',  badge: null },
    { id: 1000, quota: 1000, amount: 10500, label: '1000 Email', sub: 'Rp 10.5/email',      color: 'blue',   badge: 'Terlaris🔥' },
    { id: 2000, quota: 2000, amount: 20000, label: '2000 Email', sub: 'Rp 10/email (Hemat!)', color: 'purple', badge: null },
];

// ── INIT ───────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', async () => {
    lucide.createIcons();
    initGoogleLogin();

    if (authToken) {
        const ok = await fetchUser();
        if (ok) {
            showDashboard();
        } else {
            logout();
        }
    }
});

// ══════════════════════════════════════════════════════
// AUTH FUNCTIONS
// ══════════════════════════════════════════════════════

function showLogin() {
    document.getElementById('login-form').style.display = 'block';
    document.getElementById('register-form').style.display = 'none';
    document.getElementById('otp-form').style.display = 'none';
    clearErrors();
}

function showRegister() {
    document.getElementById('login-form').style.display = 'none';
    document.getElementById('register-form').style.display = 'block';
    document.getElementById('otp-form').style.display = 'none';
    clearErrors();
}

function showOTP(email) {
    document.getElementById('login-form').style.display = 'none';
    document.getElementById('register-form').style.display = 'none';
    document.getElementById('otp-form').style.display = 'block';
    document.getElementById('otp-email-display').textContent = email;
    clearErrors();
}

function clearErrors() {
    document.querySelectorAll('.auth-error').forEach(el => { el.textContent = ''; el.classList.remove('show'); });
}

function showError(elementId, msg) {
    const el = document.getElementById(elementId);
    el.textContent = msg;
    el.classList.add('show');
}

async function handleLogin() {
    const email = document.getElementById('login-email').value.trim();
    const password = document.getElementById('login-password').value;
    if (!email || !password) return showError('login-error', 'Email dan password wajib diisi.');

    const btn = document.getElementById('login-btn-text');
    btn.textContent = 'Memproses...';

    try {
        const res = await fetch(`${API}/api/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });
        const data = await res.json();

        if (data.status === 'success') {
            authToken = data.data.token;
            localStorage.setItem('hadirin_token', authToken);
            currentUser = data.data.user;
            showDashboard();
        } else {
            showError('login-error', data.message);
        }
    } catch (e) {
        showError('login-error', 'Gagal terhubung ke server.');
    }
    btn.textContent = 'Masuk';
}

async function handleRegister() {
    const name = document.getElementById('reg-name').value.trim();
    const email = document.getElementById('reg-email').value.trim();
    const password = document.getElementById('reg-password').value;
    if (!name || !email || !password) return showError('register-error', 'Semua field wajib diisi.');
    if (password.length < 8) return showError('register-error', 'Password minimal 8 karakter.');

    const btn = document.getElementById('reg-btn-text');
    btn.textContent = 'Memproses...';

    try {
        const res = await fetch(`${API}/api/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, email, password })
        });
        const data = await res.json();

        if (data.status === 'success') {
            showOTP(email);
        } else {
            showError('register-error', data.message);
        }
    } catch (e) {
        showError('register-error', 'Gagal terhubung ke server.');
    }
    btn.textContent = 'Daftar Sekarang';
}

async function handleVerifyOTP() {
    const email = document.getElementById('otp-email-display').textContent;
    const otp = document.getElementById('otp-code').value.trim();
    if (!otp) return showError('otp-error', 'Masukkan kode OTP.');

    const btn = document.getElementById('otp-btn-text');
    btn.textContent = 'Memverifikasi...';

    try {
        const res = await fetch(`${API}/api/auth/verify-otp`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, otp })
        });
        const data = await res.json();

        if (data.status === 'success') {
            authToken = data.data.token;
            localStorage.setItem('hadirin_token', authToken);
            currentUser = data.data.user;
            showDashboard();
        } else {
            showError('otp-error', data.message);
        }
    } catch (e) {
        showError('otp-error', 'Gagal terhubung ke server.');
    }
    btn.textContent = 'Verifikasi';
}

function initGoogleLogin() {
    if (typeof google === 'undefined') {
        // Retry after GSI library loads
        setTimeout(initGoogleLogin, 500);
        return;
    }
    google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: handleGoogleCredential,
    });
    google.accounts.id.renderButton(
        document.getElementById('google-login-btn'),
        { theme: 'outline', size: 'large', width: 380, text: 'signin_with', shape: 'rectangular', logo_alignment: 'center' }
    );
}

async function handleGoogleCredential(response) {
    try {
        const res = await fetch(`${API}/api/auth/google`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ idToken: response.credential })
        });
        const data = await res.json();

        if (data.status === 'success') {
            authToken = data.token;
            localStorage.setItem('hadirin_token', authToken);
            currentUser = data.data;
            showDashboard();
        } else {
            showError('login-error', data.message || 'Login Google gagal.');
        }
    } catch (e) {
        showError('login-error', 'Gagal terhubung ke server.');
    }
}

async function fetchUser() {
    try {
        const res = await fetch(`${API}/api/auth/me`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        const data = await res.json();
        if (data.status === 'success') {
            currentUser = data.data;
            return true;
        }
        return false;
    } catch { return false; }
}

function logout() {
    authToken = null;
    currentUser = null;
    localStorage.removeItem('hadirin_token');
    document.getElementById('auth-screen').style.display = 'flex';
    document.getElementById('dashboard-screen').style.display = 'none';
    showLogin();
}

// ══════════════════════════════════════════════════════
// DASHBOARD
// ══════════════════════════════════════════════════════

function showDashboard() {
    document.getElementById('auth-screen').style.display = 'none';
    document.getElementById('dashboard-screen').style.display = 'flex';

    // Update navbar user info
    document.getElementById('nav-username').textContent = currentUser.name || 'User';
    document.getElementById('user-avatar').textContent = (currentUser.name || 'U').charAt(0).toUpperCase();

    navigateTo('dashboard');
    lucide.createIcons();
}

function toggleSidebar() {
    document.getElementById('sidebar').classList.toggle('open');
    document.getElementById('sidebar-overlay').classList.toggle('show');
}

function navigateTo(view) {
    currentView = view;

    // Update sidebar active
    document.querySelectorAll('.sidebar-item').forEach(item => {
        item.classList.toggle('active', item.dataset.view === view);
    });

    // Close mobile sidebar
    document.getElementById('sidebar').classList.remove('open');
    document.getElementById('sidebar-overlay').classList.remove('show');

    // Render view
    const main = document.getElementById('main-content');
    switch (view) {
        case 'dashboard': renderDashboardView(main); break;
        case 'events': renderEventsView(main); break;
        case 'topup': renderTopupView(main); break;
        case 'history': renderHistoryView(main); break;
        case 'profile': renderProfileView(main); break;
        default: renderDashboardView(main);
    }

    lucide.createIcons();
    window.scrollTo({ top: 0 });
}

// ── DASHBOARD VIEW ─────────────────────────────────────

async function renderDashboardView(el) {
    await fetchUser(); // refresh quota
    el.innerHTML = `
        <div class="welcome-banner">
            <div class="welcome-text">
                <h2>👋 Halo, ${currentUser.name || 'User'}!</h2>
                <p>Kelola event dan tingkatkan pengalaman absensi dengan mudah.</p>
            </div>
            <div class="welcome-stats">
                <div class="stat-box">
                    <div class="stat-icon"><i data-lucide="send"></i></div>
                    <div class="stat-info">
                        <div class="stat-label">Terkirim</div>
                        <div class="stat-value">${currentUser.totalEmailsSent || 0}</div>
                        <div class="stat-sub">Total Email</div>
                    </div>
                </div>
                <div class="stat-box">
                    <div class="stat-icon"><i data-lucide="inbox"></i></div>
                    <div class="stat-info">
                        <div class="stat-label">Sisa Quota</div>
                        <div class="stat-value">${currentUser.emailQuota || 0}</div>
                        <div class="stat-sub">Email</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="page-header">
            <h2>Event Terbaru</h2>
            <p>Daftar event yang Anda kelola</p>
        </div>
        <div id="dashboard-events"><div class="empty-state"><div class="empty-icon"><i data-lucide="loader"></i></div><p>Memuat event...</p></div></div>

        <div class="dash-footer">© 2026 hadir.in. All rights reserved.</div>
    `;
    lucide.createIcons();
    loadEvents('dashboard-events', 5);
}

// ── EVENTS VIEW ────────────────────────────────────────

async function renderEventsView(el) {
    el.innerHTML = `
        <div class="page-header">
            <h2>Semua Event</h2>
            <p>Daftar lengkap event yang Anda kelola. Buat dan kelola event melalui aplikasi mobile.</p>
        </div>
        <div id="all-events"><div class="empty-state"><div class="empty-icon"><i data-lucide="loader"></i></div><p>Memuat event...</p></div></div>
        <div class="dash-footer">© 2026 hadir.in. All rights reserved.</div>
    `;
    lucide.createIcons();
    loadEvents('all-events', 100);
}

async function loadEvents(containerId, limit) {
    try {
        const res = await fetch(`${API}/api/events`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        const data = await res.json();
        const container = document.getElementById(containerId);

        if (data.status === 'success' && data.data && data.data.length > 0) {
            const events = data.data.slice(0, limit);
            container.innerHTML = events.map(ev => {
                const isOpen = ev.type === 'open';
                const date = new Date(ev.date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
                return `
                    <div class="event-card">
                        <div class="event-icon-box ${isOpen ? 'open' : 'closed'}">
                            <i data-lucide="${isOpen ? 'users' : 'ticket'}"></i>
                        </div>
                        <div class="event-details">
                            <div class="event-name">${ev.name}</div>
                            <div class="event-meta">${date} · ${ev.location || 'Belum ada lokasi'}</div>
                        </div>
                        <span class="event-type-badge ${isOpen ? 'open' : 'closed'}">${isOpen ? 'Terbuka' : 'Tertutup'}</span>
                    </div>
                `;
            }).join('');
        } else {
            container.innerHTML = `<div class="empty-state"><div class="empty-icon"><i data-lucide="calendar-off"></i></div><p>Belum ada event. Buat event pertama Anda melalui aplikasi mobile!</p></div>`;
        }
        lucide.createIcons();
    } catch {
        document.getElementById(containerId).innerHTML = `<div class="empty-state"><p>Gagal memuat event.</p></div>`;
    }
}

// ── TOPUP VIEW ─────────────────────────────────────────

function renderTopupView(el) {
    selectedPackage = PACKAGES[1]; // default to 1000

    el.innerHTML = `
        <div class="welcome-banner">
            <div class="welcome-text">
                <h2>👋 Halo, ${currentUser.name || 'User'}!</h2>
                <p>Kelola event dan tingkatkan pengalaman absensi dengan mudah.</p>
            </div>
            <div class="welcome-stats">
                <div class="stat-box">
                    <div class="stat-icon"><i data-lucide="send"></i></div>
                    <div class="stat-info">
                        <div class="stat-label">Terkirim</div>
                        <div class="stat-value">${currentUser.totalEmailsSent || 0}</div>
                        <div class="stat-sub">Total Email</div>
                    </div>
                </div>
                <div class="stat-box">
                    <div class="stat-icon"><i data-lucide="inbox"></i></div>
                    <div class="stat-info">
                        <div class="stat-label">Sisa Quota</div>
                        <div class="stat-value">${currentUser.emailQuota || 0}</div>
                        <div class="stat-sub">Email</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="page-header">
            <h2>Tambah Kuota Email</h2>
            <p>Pilih paket yang sesuai kebutuhan event-mu.</p>
        </div>

        <div class="topup-grid">
            <div class="dash-card">
                <h3>Pilih Paket Email</h3>
                <div class="package-list" id="package-list">
                    ${PACKAGES.map((pkg, i) => `
                        <div class="package-card ${i === 1 ? 'selected' : ''}" onclick="selectPackage(${i})" id="pkg-${i}">
                            <div class="package-radio"></div>
                            <div class="package-icon ${pkg.color}"><i data-lucide="mail"></i></div>
                            <div class="package-info">
                                <div class="package-name">${pkg.label} ${pkg.badge ? `<span class="package-badge">${pkg.badge}</span>` : ''}</div>
                                <div class="package-sub">${pkg.sub}</div>
                            </div>
                            <div class="package-price ${pkg.color}">Rp ${pkg.amount.toLocaleString('id-ID')}</div>
                            <div class="package-arrow"><i data-lucide="chevron-right"></i></div>
                        </div>
                    `).join('')}
                </div>
                <div class="secure-note">
                    <i data-lucide="lock"></i>
                    Pembayaran aman via Midtrans · Langsung aktif setelah bayar
                </div>
            </div>

            <div class="dash-card order-summary">
                <h3>Ringkasan Pesanan</h3>
                <div class="summary-row">
                    <span class="summary-label">Paket Dipilih</span>
                    <span class="summary-value" id="sum-price">Rp ${selectedPackage.amount.toLocaleString('id-ID')}</span>
                </div>
                <div class="summary-row">
                    <span class="summary-label">Jumlah Email</span>
                    <span class="summary-value" id="sum-quota">${selectedPackage.quota.toLocaleString('id-ID')} Email</span>
                </div>
                <div class="summary-row">
                    <span class="summary-label">Total Pembayaran</span>
                    <span class="summary-total" id="sum-total">Rp ${selectedPackage.amount.toLocaleString('id-ID')}</span>
                </div>
                <button class="btn-pay" onclick="handlePayment()" id="btn-pay">Lanjutkan ke Pembayaran</button>
                <div class="pay-secure"><i data-lucide="shield-check"></i> Pembayaran aman dan terenkripsi</div>
            </div>
        </div>

        <div style="margin-top:32px">
            <div class="page-header">
                <h2>Kenapa pakai Kuota Email hadir.in?</h2>
            </div>
            <div class="benefits-grid">
                <div class="benefit-card">
                    <div class="benefit-icon green"><i data-lucide="circle-check"></i></div>
                    <h4>Hemat & Fleksibel</h4>
                    <p>Bayar sesuai kebutuhan, tanpa langganan bulanan.</p>
                </div>
                <div class="benefit-card">
                    <div class="benefit-icon yellow"><i data-lucide="zap"></i></div>
                    <h4>Langsung Aktif</h4>
                    <p>Kuota email langsung bertambah setelah pembayaran.</p>
                </div>
                <div class="benefit-card">
                    <div class="benefit-icon blue"><i data-lucide="shield-check"></i></div>
                    <h4>Aman & Terpercaya</h4>
                    <p>Transaksi aman via Midtrans dengan enkripsi tinggi.</p>
                </div>
                <div class="benefit-card">
                    <div class="benefit-icon purple"><i data-lucide="mail"></i></div>
                    <h4>Kirim Tanpa Batas</h4>
                    <p>Kirim email e-ticket dan notifikasi tanpa batas waktu.</p>
                </div>
            </div>
        </div>

        <div class="dash-footer">© 2026 hadir.in. All rights reserved.</div>
    `;
    lucide.createIcons();
}

function selectPackage(index) {
    selectedPackage = PACKAGES[index];
    document.querySelectorAll('.package-card').forEach((card, i) => {
        card.classList.toggle('selected', i === index);
    });
    document.getElementById('sum-price').textContent = `Rp ${selectedPackage.amount.toLocaleString('id-ID')}`;
    document.getElementById('sum-quota').textContent = `${selectedPackage.quota.toLocaleString('id-ID')} Email`;
    document.getElementById('sum-total').textContent = `Rp ${selectedPackage.amount.toLocaleString('id-ID')}`;
}

async function handlePayment() {
    if (!selectedPackage) return;

    const btn = document.getElementById('btn-pay');
    btn.disabled = true;
    btn.textContent = 'Memproses...';

    try {
        const res = await fetch(`${API}/api/payment/create-snap`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            body: JSON.stringify({
                quota: selectedPackage.quota,
                amount: selectedPackage.amount
            })
        });
        const data = await res.json();

        if (data.status === 'success') {
            window.snap.pay(data.data.token, {
                onSuccess: async function() {
                    await fetchUser();
                    navigateTo('topup');
                    alert('🎉 Pembayaran berhasil! Kuota email Anda telah bertambah.');
                },
                onPending: function() {
                    alert('⏳ Pembayaran pending. Kuota akan bertambah setelah pembayaran dikonfirmasi.');
                    navigateTo('history');
                },
                onError: function() {
                    alert('❌ Pembayaran gagal. Silakan coba lagi.');
                },
                onClose: function() {
                    btn.disabled = false;
                    btn.textContent = 'Lanjutkan ke Pembayaran';
                }
            });
        } else {
            alert(data.message || 'Gagal membuat transaksi.');
            btn.disabled = false;
            btn.textContent = 'Lanjutkan ke Pembayaran';
        }
    } catch {
        alert('Gagal terhubung ke server.');
        btn.disabled = false;
        btn.textContent = 'Lanjutkan ke Pembayaran';
    }
}

// ── HISTORY VIEW ───────────────────────────────────────

async function renderHistoryView(el) {
    el.innerHTML = `
        <div class="page-header">
            <h2>Riwayat Pembelian</h2>
            <p>Histori transaksi pembelian kuota email Anda.</p>
        </div>
        <div class="dash-card">
            <div id="history-content"><div class="empty-state"><div class="empty-icon"><i data-lucide="loader"></i></div><p>Memuat riwayat...</p></div></div>
        </div>
        <div class="dash-footer">© 2026 hadir.in. All rights reserved.</div>
    `;
    lucide.createIcons();

    try {
        const res = await fetch(`${API}/api/payment/history`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        const data = await res.json();
        const container = document.getElementById('history-content');

        if (data.status === 'success' && data.data && data.data.length > 0) {
            container.innerHTML = `
                <div class="table-wrapper">
                    <table class="dash-table">
                        <thead>
                            <tr>
                                <th>Tanggal</th>
                                <th>Order ID</th>
                                <th>Paket</th>
                                <th>Harga</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${data.data.map(tx => {
                                const date = new Date(tx.createdAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
                                const statusClass = tx.status === 'settlement' ? 'settlement' : tx.status === 'pending' ? 'pending' : 'failure';
                                const statusLabel = tx.status === 'settlement' ? 'Berhasil' : tx.status === 'pending' ? 'Pending' : 'Gagal';
                                
                                let actionHtml = `<span class="status-badge ${statusClass}">${statusLabel}</span>`;
                                if (tx.status === 'pending' && tx.snapToken) {
                                    actionHtml += `<br><button onclick="resumePayment('${tx.snapToken}')" style="margin-top:8px; padding:6px 12px; border-radius:6px; border:none; background:var(--blue); color:white; cursor:pointer; font-size:12px; font-weight:600; font-family:'Inter',sans-serif">Bayar Sekarang</button>`;
                                }

                                return `
                                    <tr>
                                        <td>${date}</td>
                                        <td style="font-family:monospace;font-size:12px;color:var(--text-muted)">${tx.orderId}</td>
                                        <td><strong>${tx.quota.toLocaleString('id-ID')} Email</strong></td>
                                        <td>Rp ${tx.amount.toLocaleString('id-ID')}</td>
                                        <td>${actionHtml}</td>
                                    </tr>
                                `;
                            }).join('')}
                        </tbody>
                    </table>
                </div>
            `;
        } else {
            container.innerHTML = `<div class="empty-state"><div class="empty-icon"><i data-lucide="receipt"></i></div><p>Belum ada riwayat pembelian.</p></div>`;
        }
        lucide.createIcons();
    } catch {
        document.getElementById('history-content').innerHTML = `<div class="empty-state"><p>Gagal memuat riwayat.</p></div>`;
    }
}

function resumePayment(token) {
    window.snap.pay(token, {
        onSuccess: async function() {
            await fetchUser();
            navigateTo('history');
            alert('🎉 Pembayaran berhasil! Kuota email Anda telah bertambah.');
        },
        onPending: function() {
            alert('⏳ Pembayaran masih pending.');
        },
        onError: function() {
            alert('❌ Pembayaran gagal. Silakan coba lagi.');
            navigateTo('history');
        },
        onClose: function() {
            // Stay on history page
        }
    });
}

// ── PROFILE VIEW ───────────────────────────────────────

async function renderProfileView(el) {
    await fetchUser();
    el.innerHTML = `
        <div class="page-header">
            <h2>Profil Saya</h2>
            <p>Informasi akun Anda</p>
        </div>
        <div class="dash-card">
            <div class="profile-grid">
                <div>
                    <div class="profile-info-item">
                        <label>Nama Lengkap</label>
                        <div class="value">${currentUser.name || '-'}</div>
                    </div>
                    <div class="profile-info-item">
                        <label>Email</label>
                        <div class="value">${currentUser.email || '-'}</div>
                    </div>
                    <div class="profile-info-item">
                        <label>Role</label>
                        <div class="value" style="text-transform:capitalize">${currentUser.role || 'organizer'}</div>
                    </div>
                </div>
                <div>
                    <div class="profile-info-item">
                        <label>Sisa Kuota Email</label>
                        <div class="value" style="color:var(--green);font-size:24px;font-family:'Outfit',sans-serif">${currentUser.emailQuota || 0}</div>
                    </div>
                    <div class="profile-info-item">
                        <label>Total Email Terkirim</label>
                        <div class="value" style="font-size:24px;font-family:'Outfit',sans-serif">${currentUser.totalEmailsSent || 0}</div>
                    </div>
                    <div class="profile-info-item">
                        <label>Status Akun</label>
                        <div class="value"><span class="status-badge settlement">${currentUser.isVerified ? 'Terverifikasi' : 'Belum Verifikasi'}</span></div>
                    </div>
                </div>
            </div>
        </div>
        <button class="btn-logout" onclick="logout()"><i data-lucide="log-out" style="width:16px;height:16px;margin-right:8px"></i> Keluar dari Akun</button>
        <div class="dash-footer">© 2026 hadir.in. All rights reserved.</div>
    `;
    lucide.createIcons();
}

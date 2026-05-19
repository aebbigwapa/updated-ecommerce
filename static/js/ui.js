/**
 * ui.js — Shared UI helpers
 * Used by: admin.js, seller.js, rider.js, buyer.js
 */

// ── Toast ─────────────────────────────────────────────────────
function showToast(msg, isError = false) {
    const t = document.getElementById('toast');
    if (!t) return;
    t.textContent = msg;
    t.style.background = isError ? '#c0392b' : '#1a1a3e';
    t.classList.add('show');
    setTimeout(() => t.classList.remove('show'), 3000);
}

// ── Modal ─────────────────────────────────────────────────────
function openModal(id) {
    document.getElementById(id)?.classList.add('open');
}

function closeModal(id) {
    document.getElementById(id)?.classList.remove('open');
}

// ── Popup ─────────────────────────────────────────────────────
function showPopup(icon, title, msg) {
    document.getElementById('popupIcon').textContent  = icon;
    document.getElementById('popupTitle').textContent = title;
    document.getElementById('popupMsg').textContent   = msg;
    document.getElementById('popupOverlay').classList.add('open');
}

function closePopup() {
    document.getElementById('popupOverlay')?.classList.remove('open');
}

// ── Formatters ────────────────────────────────────────────────
function formatDate(iso) {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString('en-PH', {
        year: 'numeric', month: 'short', day: 'numeric'
    });
}

function formatCurrency(amount) {
    return '₱' + Number(amount || 0).toLocaleString('en-PH', {
        minimumFractionDigits: 2
    });
}

// ── File upload label ─────────────────────────────────────────
function showName(input, targetId) {
    const el = document.getElementById(targetId);
    if (el) el.textContent = input.files[0] ? '✅ ' + input.files[0].name : '';
}

// ── Logout confirmation ──────────────────────────────────────
function confirmLogout(e) {
    e.preventDefault();
    const href = e.currentTarget.href || '/logout';

    // Inject modal once
    if (!document.getElementById('logoutConfirmModal')) {
        const el = document.createElement('div');
        el.id = 'logoutConfirmModal';
        el.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:9999;display:flex;align-items:center;justify-content:center;padding:16px';
        el.innerHTML = `
            <div style="background:#fff;border-radius:18px;padding:28px 24px;width:100%;max-width:360px;text-align:center;box-shadow:0 20px 60px rgba(0,0,0,.18);animation:_lci .2s ease">
                <div style="font-size:44px;margin-bottom:12px">🚪</div>
                <div style="font-size:18px;font-weight:700;color:#1a1a3e;margin-bottom:8px">Log out?</div>
                <div style="font-size:14px;color:#6c757d;margin-bottom:24px">Are you sure you want to log out?</div>
                <div style="display:flex;gap:10px;justify-content:center">
                    <button id="logoutCancelBtn" style="flex:1;padding:11px;border-radius:10px;border:1.5px solid #e8e8f0;background:#fff;font-size:14px;font-weight:600;color:#1a1a3e;cursor:pointer">Cancel</button>
                    <button id="logoutConfirmBtn" style="flex:1;padding:11px;border-radius:10px;border:none;background:linear-gradient(135deg,#FF2BAC,#FF6BCE);color:#fff;font-size:14px;font-weight:600;cursor:pointer">Yes, Log out</button>
                </div>
            </div>
            <style>@keyframes _lci{from{transform:scale(.92);opacity:0}to{transform:scale(1);opacity:1}}</style>
        `;
        document.body.appendChild(el);
        document.getElementById('logoutCancelBtn').onclick  = () => el.remove();
        document.getElementById('logoutConfirmBtn').onclick = () => { window.location.href = href; };
        el.addEventListener('click', ev => { if (ev.target === el) el.remove(); });
    }
}

// ── Mobile sidebar toggle ─────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    const toggle  = document.getElementById('sidebarToggle');
    const sidebar = document.querySelector('.sidebar');
    const overlay = document.getElementById('sidebarOverlay');

    if (toggle && sidebar) {
        toggle.addEventListener('click', () => {
            sidebar.classList.toggle('open');
            if (overlay) overlay.style.display =
                sidebar.classList.contains('open') ? 'block' : 'none';
        });
    }

    if (overlay) {
        overlay.addEventListener('click', () => {
            sidebar?.classList.remove('open');
            overlay.style.display = 'none';
        });
    }

    // Wire logout confirmation to all logout links
    document.querySelectorAll('a.logout-link, a[href="/logout"]').forEach(link => {
        link.addEventListener('click', confirmLogout);
    });
});

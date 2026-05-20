// ── Step navigation ───────────────────────────────────────────
let currentStep = 1;

function goToStep(step) {
    if (step === 2 && !validateStep1()) return;
    if (step === 3 && !validateStep2()) return;

    document.querySelectorAll('.step-content').forEach(s => s.style.display = 'none');
    document.getElementById(`step${step}`).style.display = 'block';

    for (let i = 1; i <= 3; i++) {
        const ind  = document.getElementById(`ind${i}`);
        const circ = ind.querySelector('.step-circle');
        ind.classList.remove('active', 'done');
        if (i < step)   { ind.classList.add('done');   circ.textContent = '✓'; }
        if (i === step) { ind.classList.add('active'); circ.textContent = i;  }
        if (i > step)   circ.textContent = i;
    }

    document.querySelectorAll('.step-line').forEach((line, idx) => {
        line.classList.toggle('done', idx + 1 < step);
    });

    if (step === 3 && !window._psgcInited) {
        setTimeout(() => { initPSGC(); window._psgcInited = true; }, 150);
    } else if (step === 3 && psgcMap) {
        setTimeout(() => psgcMap.invalidateSize(), 150);
    }

    if (step === 2) showDocSection();
    currentStep = step;
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function showDocSection() {
    const role = document.querySelector('input[name="role"]:checked').value;
    document.getElementById('buyerDocs').style.display  = role === 'buyer'  ? 'block' : 'none';
    document.getElementById('sellerDocs').style.display = role === 'seller' ? 'block' : 'none';
    document.getElementById('riderDocs').style.display  = role === 'rider'  ? 'block' : 'none';
}

// ── Alerts ────────────────────────────────────────────────────
function showError(msg) {
    const el = document.getElementById('errorMsg');
    el.textContent   = msg;
    el.style.display = 'block';
    setTimeout(() => el.style.display = 'none', 5000);
}

function showSuccess(msg) {
    const el = document.getElementById('successMsg');
    el.textContent   = msg;
    el.style.display = 'block';
    setTimeout(() => el.style.display = 'none', 4000);
}

// ── Password strength & rules ─────────────────────────────────
const RULES = [
    { id: 'rule-len',     test: v => v.length >= 8 },
    { id: 'rule-upper',   test: v => /[A-Z]/.test(v) },
    { id: 'rule-lower',   test: v => /[a-z]/.test(v) },
    { id: 'rule-digit',   test: v => /[0-9]/.test(v) },
    { id: 'rule-special', test: v => /[!@#$%^&*()\-_=+\[\]{}|;:'",.<>?/\\]/.test(v) },
];

const STRENGTH_LEVELS = [
    { label: '',          color: '',        w: '0%'   },
    { label: 'Weak',      color: '#e74c3c', w: '20%'  },
    { label: 'Fair',      color: '#e67e22', w: '40%'  },
    { label: 'Moderate',  color: '#f1c40f', w: '60%'  },
    { label: 'Good',      color: '#2980b9', w: '80%'  },
    { label: 'Strong 💪', color: '#2ecc71', w: '100%' },
];

function isPasswordValid(v) {
    return RULES.every(r => r.test(v));
}

const pwInput = document.getElementById('password');
const fill    = document.getElementById('strengthFill');
const text    = document.getElementById('strengthText');

pwInput.addEventListener('input', () => {
    const v = pwInput.value;
    let score = 0;
    RULES.forEach(r => {
        const el = document.getElementById(r.id);
        const ok = r.test(v);
        if (ok) { score++; el.classList.add('rule-ok'); el.classList.remove('rule-fail'); }
        else    { el.classList.remove('rule-ok'); if (v) el.classList.add('rule-fail'); else el.classList.remove('rule-fail'); }
    });
    const l = v ? STRENGTH_LEVELS[score] : STRENGTH_LEVELS[0];
    fill.style.width      = l.w;
    fill.style.background = l.color;
    text.textContent      = l.label;
    text.style.color      = l.color;
    // Re-check confirm match
    document.getElementById('confirm_password').dispatchEvent(new Event('input'));
});

document.getElementById('confirm_password').addEventListener('input', function () {
    const ct = document.getElementById('confirmText');
    if (!this.value) { ct.textContent = ''; return; }
    const match = this.value === pwInput.value;
    ct.textContent = match ? '✅ Passwords match' : '❌ Passwords do not match';
    ct.style.color = match ? '#2ecc71' : '#e74c3c';
});

document.getElementById('pwToggle').addEventListener('click', function () {
    const isText = pwInput.type === 'text';
    pwInput.type     = isText ? 'password' : 'text';
    this.textContent = isText ? '👁️' : '🙈';
});

document.getElementById('pwToggle2').addEventListener('click', function () {
    const cpw = document.getElementById('confirm_password');
    const isText = cpw.type === 'text';
    cpw.type         = isText ? 'password' : 'text';
    this.textContent = isText ? '👁️' : '🙈';
});

// ── Phone validation ──────────────────────────────────────────
// Extensible country rules map: { code: { min, max, pattern, placeholder, label } }
// min === max means exact length required.
const PHONE_RULES = {
    '+1':   { min: 10, max: 10, pattern: /^[2-9]\d{9}$/,        placeholder: '2XXXXXXXXX',   label: 'US/Canada' },
    '+44':  { min: 10, max: 10, pattern: /^7\d{9}$/,             placeholder: '7XXXXXXXXX',   label: 'UK' },
    '+63':  { min: 10, max: 10, pattern: /^9\d{9}$/,             placeholder: '9XXXXXXXXX',   label: 'Philippines' },
    '+91':  { min: 10, max: 10, pattern: /^[6-9]\d{9}$/,         placeholder: '9XXXXXXXXX',   label: 'India' },
    '+81':  { min: 10, max: 10, pattern: /^[789]0\d{8}$/,        placeholder: '90XXXXXXXX',   label: 'Japan' },
    '+86':  { min: 11, max: 11, pattern: /^1[3-9]\d{9}$/,        placeholder: '1XXXXXXXXXX',  label: 'China' },
    '+61':  { min: 9,  max: 9,  pattern: /^4\d{8}$/,             placeholder: '4XXXXXXXX',    label: 'Australia' },
    '+49':  { min: 10, max: 11, pattern: /^1[5-7]\d{8,9}$/,      placeholder: '15XXXXXXXXX',  label: 'Germany' },
    '+33':  { min: 9,  max: 9,  pattern: /^[67]\d{8}$/,          placeholder: '6XXXXXXXX',    label: 'France' },
    '+7':   { min: 10, max: 10, pattern: /^9\d{9}$/,             placeholder: '9XXXXXXXXX',   label: 'Russia' },
    '+55':  { min: 10, max: 11, pattern: /^[1-9][1-9]\d{8,9}$/,  placeholder: '11XXXXXXXXX',  label: 'Brazil' },
    '+65':  { min: 8,  max: 8,  pattern: /^[89]\d{7}$/,          placeholder: '8XXXXXXX',     label: 'Singapore' },
    '+60':  { min: 9,  max: 10, pattern: /^1\d{8,9}$/,           placeholder: '1XXXXXXXXX',   label: 'Malaysia' },
    '+66':  { min: 9,  max: 9,  pattern: /^[689]\d{8}$/,         placeholder: '8XXXXXXXX',    label: 'Thailand' },
    '+82':  { min: 9,  max: 10, pattern: /^1[0-9]\d{7,8}$/,      placeholder: '10XXXXXXXX',   label: 'South Korea' },
    '+971': { min: 9,  max: 9,  pattern: /^5\d{8}$/,             placeholder: '5XXXXXXXX',    label: 'UAE' },
    '+966': { min: 9,  max: 9,  pattern: /^5\d{8}$/,             placeholder: '5XXXXXXXX',    label: 'Saudi Arabia' },
};
const PHONE_DEFAULT = { min: 4, max: 15, pattern: /^\d{4,15}$/, placeholder: 'Enter number', label: 'International' };

const phoneCountryEl = document.getElementById('phoneCountry');
const phoneNumberEl  = document.getElementById('phone');
const phoneHintEl    = document.getElementById('phoneHint');

function getPhoneRule() {
    return PHONE_RULES[phoneCountryEl.value] || PHONE_DEFAULT;
}

function _phoneHintText(rule, digits) {
    const code = phoneCountryEl.value;
    if (rule.min === rule.max) {
        return digits === rule.max
            ? `✅ Valid number for ${code}`
            : `Enter exactly ${rule.max} digits for ${code}`;
    }
    if (digits < rule.min) return `Enter ${rule.min}–${rule.max} digits for ${code} (${digits} entered)`;
    if (digits > rule.max) return `Maximum ${rule.max} digits for ${code}`;
    return `✅ Valid number for ${code}`;
}

function _applyPhoneRule() {
    const rule   = getPhoneRule();
    const digits = phoneNumberEl.value.replace(/\D/g, '');
    phoneNumberEl.setAttribute('maxlength', String(rule.max));
    phoneNumberEl.placeholder = rule.placeholder;

    if (!digits) {
        const msg = rule.min === rule.max
            ? `Enter exactly ${rule.max} digits for ${phoneCountryEl.value}`
            : `Enter ${rule.min}–${rule.max} digits for ${phoneCountryEl.value}`;
        phoneHintEl.textContent = msg;
        phoneHintEl.style.color = 'var(--gray)';
        return;
    }

    const ok = rule.pattern.test(digits) && digits.length >= rule.min && digits.length <= rule.max;
    phoneHintEl.textContent = _phoneHintText(rule, digits.length);
    phoneHintEl.style.color = ok ? '#2ecc71' : '#e74c3c';
}

function validatePhone() {
    const rule   = getPhoneRule();
    const digits = phoneNumberEl.value.replace(/\D/g, '');
    if (!digits) return false;
    return rule.pattern.test(digits) && digits.length >= rule.min && digits.length <= rule.max;
}

phoneCountryEl.addEventListener('change', () => {
    const rule      = getPhoneRule();
    const prevDigits = phoneNumberEl.value.replace(/\D/g, '');
    // Truncate if current value exceeds new country's max
    if (prevDigits.length > rule.max) {
        phoneNumberEl.value = prevDigits.slice(0, rule.max);
        phoneHintEl.textContent = `Number truncated to ${rule.max} digits for ${phoneCountryEl.value}`;
        phoneHintEl.style.color = '#e67e22';
        setTimeout(_applyPhoneRule, 1500);
    } else {
        _applyPhoneRule();
    }
    phoneNumberEl.focus();
});

// Hard keystroke limiter — block input beyond max length
phoneNumberEl.addEventListener('keydown', (e) => {
    const rule   = getPhoneRule();
    const digits = phoneNumberEl.value.replace(/\D/g, '');
    const isDigit = /^[0-9]$/.test(e.key);
    const isControl = e.ctrlKey || e.metaKey || e.altKey ||
        ['Backspace','Delete','ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Tab','Home','End'].includes(e.key);
    if (isDigit && digits.length >= rule.max) {
        e.preventDefault();
        phoneHintEl.textContent = `Maximum ${rule.max} digits for ${phoneCountryEl.value}`;
        phoneHintEl.style.color = '#e74c3c';
        return;
    }
    if (!isDigit && !isControl) {
        e.preventDefault(); // block non-digit, non-control keys
    }
});

// Strip any non-digit on paste/input and enforce max
phoneNumberEl.addEventListener('input', () => {
    const rule = getPhoneRule();
    let digits = phoneNumberEl.value.replace(/\D/g, '');
    if (digits.length > rule.max) digits = digits.slice(0, rule.max);
    phoneNumberEl.value = digits;
    _applyPhoneRule();
});

// Show hint on focus
phoneNumberEl.addEventListener('focus', _applyPhoneRule);

// Initialise hint on page load
_applyPhoneRule();

function getE164Phone() {
    const digits = phoneNumberEl.value.replace(/\D/g, '');
    return phoneCountryEl.value + digits;
}

// ── OTP state ─────────────────────────────────────────────────
let _otpExpireInterval  = null;
let _resendCoolInterval = null;
let _otpExpired         = false;
let _resendCount        = 0;
const MAX_RESENDS       = 3;
const OTP_DURATION_SEC  = 60;   // 1 minute
const RESEND_COOLDOWN   = 60;   // 60 seconds

function _clearOtpTimers() {
    clearInterval(_otpExpireInterval);
    clearInterval(_resendCoolInterval);
}

function startOtpExpireTimer() {
    _otpExpired = false;
    const timerEl = document.getElementById('otpTimer');
    const otpInput = document.getElementById('otp');
    let remaining = OTP_DURATION_SEC;

    const tick = () => {
        const m = Math.floor(remaining / 60).toString().padStart(2, '0');
        const s = (remaining % 60).toString().padStart(2, '0');
        timerEl.textContent = `Code expires in ${m}:${s}`;
        timerEl.style.color = remaining <= 15 ? '#e74c3c' : 'var(--pink)';
        if (remaining <= 0) {
            clearInterval(_otpExpireInterval);
            timerEl.textContent = '⚠️ Code expired. Please resend.';
            timerEl.style.color = '#e74c3c';
            otpInput.disabled   = true;
            otpInput.value      = '';
            _otpExpired         = true;
            // Enable resend immediately if expired (bypass cooldown)
            const resendBtn = document.getElementById('resendOtpBtn');
            resendBtn.disabled    = false;
            resendBtn.textContent = 'Resend Code';
            document.getElementById('resendCountdown').textContent = '';
            clearInterval(_resendCoolInterval);
        }
        remaining--;
    };
    tick();
    clearInterval(_otpExpireInterval);
    _otpExpireInterval = setInterval(tick, 1000);
}

function startResendCooldown() {
    const resendBtn  = document.getElementById('resendOtpBtn');
    const countdownEl = document.getElementById('resendCountdown');
    resendBtn.disabled = true;
    let remaining = RESEND_COOLDOWN;

    const tick = () => {
        countdownEl.textContent = `Resend in ${remaining}s`;
        if (remaining <= 0) {
            clearInterval(_resendCoolInterval);
            if (!_otpExpired) {
                resendBtn.disabled    = false;
                resendBtn.textContent = 'Resend Code';
            }
            countdownEl.textContent = '';
        }
        remaining--;
    };
    tick();
    clearInterval(_resendCoolInterval);
    _resendCoolInterval = setInterval(tick, 1000);
}

function updateResendAttemptsMsg() {
    const el = document.getElementById('otpAttemptsMsg');
    const left = MAX_RESENDS - _resendCount;
    if (_resendCount >= MAX_RESENDS) {
        el.textContent = '⛔ Maximum resend attempts reached. Please wait or contact support.';
        el.style.color = '#e74c3c';
        document.getElementById('resendOtpBtn').disabled = true;
    } else if (_resendCount > 0) {
        el.textContent = `${left} resend attempt${left !== 1 ? 's' : ''} remaining.`;
        el.style.color = '#e67e22';
    } else {
        el.textContent = '';
    }
}

async function sendOTP() {
    const email = document.getElementById('email').value.trim();
    if (!email) { showError('Enter your email first.'); return; }

    const btn = document.getElementById('sendOtpBtn');
    btn.disabled    = true;
    btn.textContent = 'Sending...';

    try {
        const res  = await fetch('/api/auth/send-otp', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email }),
        });
        const data = await res.json();

        if (res.ok) {
            document.getElementById('otpGroup').style.display = 'block';
            const otpInput = document.getElementById('otp');
            otpInput.disabled = false;
            otpInput.value    = '';
            otpInput.focus();
            _clearOtpTimers();
            startOtpExpireTimer();
            startResendCooldown();
            showSuccess('OTP sent! Check your email.');
        } else {
            showError(data.error || 'Failed to send OTP');
            btn.disabled    = false;
            btn.textContent = 'Send OTP';
        }
    } catch {
        showError('Network error');
        btn.disabled    = false;
        btn.textContent = 'Send OTP';
    }
}

async function resendOTP() {
    if (_resendCount >= MAX_RESENDS) {
        showError('Maximum resend attempts reached. Please wait or contact support.');
        return;
    }

    const email = document.getElementById('email').value.trim();
    const resendBtn = document.getElementById('resendOtpBtn');
    resendBtn.disabled    = true;
    resendBtn.textContent = 'Sending...';

    try {
        const res  = await fetch('/api/auth/send-otp', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email }),
        });
        const data = await res.json();

        if (res.ok) {
            _resendCount++;
            updateResendAttemptsMsg();
            const otpInput = document.getElementById('otp');
            otpInput.disabled = false;
            otpInput.value    = '';
            otpInput.focus();
            _clearOtpTimers();
            _otpExpired = false;
            startOtpExpireTimer();
            startResendCooldown();
            showSuccess('New OTP sent! Check your email.');
        } else {
            showError(data.error || 'Failed to resend OTP');
            resendBtn.disabled    = false;
            resendBtn.textContent = 'Resend Code';
        }
    } catch {
        showError('Network error');
        resendBtn.disabled    = false;
        resendBtn.textContent = 'Resend Code';
    }
}

async function verifyOTP() {
    const email = document.getElementById('email').value.trim();
    const otp   = document.getElementById('otp').value.trim();
    if (!otp || otp.length !== 6) return;

    try {
        const res  = await fetch('/api/auth/verify-otp', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, otp }),
        });
        const data = await res.json();

        if (res.ok) {
            document.getElementById('otp').dataset.verified = 'true';
            _clearOtpTimers();
            document.getElementById('otpTimer').textContent = '✅ Email verified';
            document.getElementById('otpTimer').style.color = '#2ecc71';
            document.getElementById('resendOtpBtn').style.display = 'none';
            document.getElementById('resendCountdown').textContent = '';
            showSuccess('Email verified!');
        } else {
            showError(data.error || 'Invalid OTP');
        }
    } catch {
        showError('Network error');
    }
}

document.getElementById('otp').addEventListener('input', (e) => {
    // Only digits
    e.target.value = e.target.value.replace(/\D/g, '');
    if (e.target.value.length === 6) verifyOTP();
});

// ── Step validation ───────────────────────────────────────────
function validateStep1() {
    const g = (id) => document.getElementById(id)?.value.trim();

    if (!g('first_name'))  { showError('First name is required.'); return false; }
    if (!g('last_name'))   { showError('Last name is required.'); return false; }
    if (!g('email'))       { showError('Email is required.'); return false; }

    if (document.getElementById('otp').dataset.verified !== 'true') {
        showError('Please verify your email with OTP first.'); return false;
    }

    if (!validatePhone()) { showError('Please enter a valid phone number.'); return false; }

    const gender = document.querySelector('input[name="gender"]:checked');
    if (!gender) { showError('Please select your gender.'); return false; }

    const pw  = document.getElementById('password').value;
    const cpw = document.getElementById('confirm_password').value;

    if (!isPasswordValid(pw)) {
        showError('Password does not meet all requirements.'); return false;
    }
    if (pw !== cpw) { showError('Passwords do not match.'); return false; }

    return true;
}

function validateStep2() {
    const role = document.querySelector('input[name="role"]:checked').value;

    if (role === 'buyer') {
        if (!document.getElementById('buyer_valid_id')?.files[0]) {
            showError('Please upload a valid ID.'); return false;
        }
    }
    if (role === 'seller') {
        if (!document.getElementById('store_name')?.value.trim()) {
            showError('Store name is required.'); return false;
        }
        if (!document.querySelector('input[name="store_category"]:checked')) {
            showError('Please select a store category.'); return false;
        }
    }
    if (role === 'rider') {
        if (!document.getElementById('license_number')?.value.trim()) {
            showError('License number is required.'); return false;
        }
    }
    return true;
}

// ── File upload label ─────────────────────────────────────────
function showName(input, targetId) {
    document.getElementById(targetId).textContent = input.files[0] ? '✅ ' + input.files[0].name : '';
}

// ── Submit ────────────────────────────────────────────────────
document.getElementById('registerForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const errorMsg   = document.getElementById('errorMsg');
    const successMsg = document.getElementById('successMsg');
    const btn        = document.getElementById('submitBtn');
    const role       = document.querySelector('input[name="role"]:checked').value;
    const g          = (id) => document.getElementById(id);
    const addr       = getPSGCValues();

    errorMsg.style.display   = 'none';
    successMsg.style.display = 'none';
    btn.disabled    = true;
    btn.textContent = 'Submitting...';

    const fd = new FormData();
    fd.append('first_name',  g('first_name').value.trim());
    fd.append('middle_name', g('middle_name')?.value.trim() || '');
    fd.append('last_name',   g('last_name').value.trim());
    fd.append('email',       g('email').value.trim());
    fd.append('phone',       getE164Phone());
    fd.append('gender',      document.querySelector('input[name="gender"]:checked').value);
    fd.append('password',    g('password').value);
    fd.append('role',        role);
    fd.append('otp_verified', g('otp').dataset.verified === 'true' ? 'true' : 'false');
    fd.append('region',      addr.region);
    fd.append('province',    addr.province);
    fd.append('city',        addr.city);
    fd.append('barangay',    addr.barangay);
    fd.append('street',      addr.street);
    fd.append('zip_code',    addr.zip_code);
    fd.append('latitude',    addr.latitude  || '');
    fd.append('longitude',   addr.longitude || '');

    if (role === 'buyer') {
        const buyerId = g('buyer_valid_id').files[0];
        if (buyerId) fd.append('valid_id', buyerId);
    } else if (role === 'seller') {
        fd.append('store_name',        g('store_name').value.trim());
        fd.append('store_description', g('store_description').value.trim());
        const category = document.querySelector('input[name="store_category"]:checked');
        if (category) fd.append('store_category', category.value);
        const validId = g('valid_id').files[0];
        const bp      = g('business_permit').files[0];
        const dti     = g('dti_sec').files[0];
        if (validId) fd.append('valid_id', validId);
        if (bp)      fd.append('business_permit', bp);
        if (dti)     fd.append('dti_or_sec', dti);
    } else if (role === 'rider') {
        fd.append('vehicle_type',   g('vehicle_type').value.trim());
        fd.append('license_number', g('license_number').value.trim());
        const dl  = g('driver_license').files[0];
        const vid = g('rider_valid_id').files[0];
        if (dl)  fd.append('driver_license', dl);
        if (vid) fd.append('valid_id', vid);
    }

    try {
        const res  = await fetch('/api/auth/register', { method: 'POST', body: fd });
        const data = await res.json();

        if (res.ok) {
            successMsg.textContent   = data.message;
            successMsg.style.display = 'block';
            document.getElementById('registerForm').reset();
            fill.style.width = '0'; text.textContent = '';
            setTimeout(() => window.location.href = '/login', 3000);
        } else {
            errorMsg.textContent   = data.error || 'Something went wrong.';
            errorMsg.style.display = 'block';
        }
    } catch {
        errorMsg.textContent   = 'Network error. Please try again.';
        errorMsg.style.display = 'block';
    }

    btn.disabled    = false;
    btn.textContent = 'Create Account';
});

// Toggle password visibility
document.getElementById('togglePw').addEventListener('click', function () {
    const pw = document.getElementById('password');
    const isText = pw.type === 'text';
    pw.type = isText ? 'password' : 'text';
    this.textContent = isText ? '👁️' : '🙈';
});

// Popup helpers
function showPopup(icon, title, msg) {
    document.getElementById('popupIcon').textContent  = icon;
    document.getElementById('popupTitle').textContent = title;
    document.getElementById('popupMsg').textContent   = msg;
    document.getElementById('popupOverlay').classList.add('open');
}

function closePopup() {
    document.getElementById('popupOverlay').classList.remove('open');
}

// Login form submit
document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const submitBtn = document.getElementById('submitBtn');
    submitBtn.disabled    = true;
    submitBtn.textContent = 'Signing in...';

    let captchaResponse = '';
    if (typeof grecaptcha !== 'undefined') {
        captchaResponse = grecaptcha.getResponse() || '';
    }

    // Show immediate feedback
    showPopup('⏳', 'Signing In', 'Please wait...');

    const res  = await fetch('/login', {
        method: 'POST',
        credentials: 'include',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            email:    document.getElementById('email').value.trim(),
            password: document.getElementById('password').value,
            'g-recaptcha-response': captchaResponse
        }),
    });

    const data = await res.json();

    if (res.ok) {
        // Check for Buy Now intent in sessionStorage
        const buyNowIntent = sessionStorage.getItem('buy_now_intent');
        let redirectUrl = data.redirect || '/';
        
        // Check URL parameter for return_to
        const urlParams = new URLSearchParams(window.location.search);
        const returnTo = urlParams.get('return_to');
        
        if (returnTo === 'buy_now' && buyNowIntent) {
            // Restore Buy Now intent and redirect to product page to complete purchase
            try {
                const intent = JSON.parse(buyNowIntent);
                // Store in server session via API
                await fetch('/buyer/api/buy-now', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(intent)
                });
                sessionStorage.removeItem('buy_now_intent');
                redirectUrl = '/buyer/checkout?mode=buy_now';
            } catch (err) {
                console.error('Failed to restore buy now intent:', err);
            }
        } else if (returnTo && returnTo.startsWith('/')) {
            redirectUrl = returnTo;
        }
        
        let countdown = 3;
        
        // Update popup to show countdown
        document.getElementById('popupIcon').textContent = '✅';
        document.getElementById('popupTitle').textContent = 'Login Successful';
        document.getElementById('popupMsg').textContent = `Redirecting in ${countdown} seconds...`;
        
        const countdownInterval = setInterval(() => {
            countdown--;
            document.getElementById('popupMsg').textContent = `Redirecting in ${countdown} seconds...`;
            if (countdown <= 0) {
                clearInterval(countdownInterval);
                closePopup();
                window.location.href = redirectUrl;
            }
        }, 1000);
        
        if (typeof grecaptcha !== 'undefined') {
            grecaptcha.reset();
        }
    } else {
        closePopup();
        submitBtn.disabled    = false;
        submitBtn.textContent = 'Sign In';

        const msg = data.error || 'Login failed.';
        if (msg.includes('pending')) {
            showPopup('⏳', 'Application Pending', msg);
        } else if (msg.includes('rejected')) {
            showPopup('❌', 'Application Rejected', msg);
        } else if (msg.includes('CAPTCHA')) {
            showPopup('🤖', 'CAPTCHA Failed', msg);
        } else {
            showPopup('🔒', 'Login Failed', msg);
        }

        if (typeof grecaptcha !== 'undefined') {
            grecaptcha.reset();
        }
    }
});

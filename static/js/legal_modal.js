// Legal Modal Functions
let currentLegalType = 'terms';

function showLegalModal(type) {
    currentLegalType = type;
    const modalOverlay = document.getElementById('legalModalOverlay');
    const modalTitle = document.getElementById('legalModalTitle');
    const modalContent = document.getElementById('legalModalContent');
    
    // Set title based on type
    if (type === 'terms') {
        modalTitle.textContent = 'Terms & Conditions';
    } else if (type === 'privacy') {
        modalTitle.textContent = 'Privacy Policy';
    }
    
    // Load content via AJAX
    loadLegalContent(type, modalContent);
    
    // Show modal
    modalOverlay.style.display = 'flex';
    document.body.style.overflow = 'hidden'; // Prevent scrolling
}

function closeLegalModal() {
    const modalOverlay = document.getElementById('legalModalOverlay');
    modalOverlay.style.display = 'none';
    document.body.style.overflow = 'auto'; // Re-enable scrolling
}

function loadLegalContent(type, targetElement) {
    const contentUrl = type === 'terms' ? '/terms-content' : '/privacy-content';
    
    // Show loading state
    targetElement.innerHTML = '<div class="legal-loading">Loading...</div>';
    
    // Fetch content
    fetch(contentUrl)
        .then(response => {
            if (!response.ok) {
                throw new Error('Failed to load content');
            }
            return response.text();
        })
        .then(html => {
            targetElement.innerHTML = html;
        })
        .catch(error => {
            console.error('Error loading legal content:', error);
            targetElement.innerHTML = '<div class="legal-error">Failed to load content. Please try again.</div>';
        });
}

// Form validation for terms checkbox
function validateTerms() {
    const termsCheckbox = document.getElementById('agreeTerms');
    const termsError = document.getElementById('termsError');
    
    if (!termsCheckbox.checked) {
        termsError.style.display = 'block';
        return false;
    }
    
    termsError.style.display = 'none';
    return true;
}

// Initialize modal functionality after DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Close modal when clicking outside content
    const modalOverlay = document.getElementById('legalModalOverlay');
    if (modalOverlay) {
        modalOverlay.addEventListener('click', function(e) {
            if (e.target === this) {
                closeLegalModal();
            }
        });
    }
    
    // Close modal with Escape key
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && document.getElementById('legalModalOverlay')?.style.display === 'flex') {
            closeLegalModal();
        }
    });
    
    // Add terms validation to form submission
    const registerForm = document.getElementById('registerForm');
    if (registerForm) {
        registerForm.addEventListener('submit', function(e) {
            if (!validateTerms()) {
                e.preventDefault();
                e.stopPropagation();
                
                // Scroll to terms checkbox if not visible
                const termsContainer = document.querySelector('.terms-checkbox-container');
                if (termsContainer) {
                    termsContainer.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
                return false;
            }
        });
    }
    
    // Also validate when clicking submit button
    const submitBtn = document.getElementById('submitBtn');
    if (submitBtn) {
        submitBtn.addEventListener('click', function(e) {
            if (this.type === 'submit' && !validateTerms()) {
                e.preventDefault();
                const termsContainer = document.querySelector('.terms-checkbox-container');
                if (termsContainer) {
                    termsContainer.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
            }
        });
    }
    
    // Add real-time validation for terms checkbox
    const termsCheckbox = document.getElementById('agreeTerms');
    if (termsCheckbox) {
        termsCheckbox.addEventListener('change', function() {
            const termsError = document.getElementById('termsError');
            if (this.checked) {
                termsError.style.display = 'none';
            }
        });
    }
});
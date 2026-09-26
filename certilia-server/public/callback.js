// Script of the proxy's callback page (/api/auth/callback). The proxy has
// already stored the result for the polling flow before rendering this page.
// The script hands the result to the in-app WebView interface
// (window.OAuthCallback) when the app provides one, follows a configured deep
// link, and closes the window.
//
// It does not post the code to window.opener. Without an allowed-origins list
// that message would reach any page that opened this one, including a page
// that started the login itself to collect someone else's code. Neither SDK
// flow reads it: the WebView flow watches the URL, the web flow polls.

(function() {
    'use strict';

    const text = (id) => document.getElementById(id)?.textContent || '';
    const success = text('oauth-success') === 'true';
    const result = {
        success: success,
        code: text('oauth-code'),
        state: text('oauth-state'),
        error: text('oauth-error'),
        errorDescription: text('oauth-error-description'),
    };
    console.log('Certilia callback page, success:', success);

    // Only the app's own WebView defines this interface.
    if (window.OAuthCallback) {
        try {
            window.OAuthCallback.onComplete(result);
        } catch (e) {
            console.error('OAuthCallback.onComplete failed:', e);
        }
    }

    const deepLinkElement = document.getElementById('deep-link');
    const deepLink = deepLinkElement?.textContent || deepLinkElement?.getAttribute('data-link');
    if (deepLink && deepLink !== 'null') {
        setTimeout(() => { window.location.href = deepLink; }, 1000);
    }

    // The web flow's polling picks up the result within about two seconds
    // and closes the popup itself; this is the fallback.
    setTimeout(() => {
        try {
            window.close();
        } catch (e) {
            console.error('Could not close window:', e);
        }
    }, 3000);
})();

// Function for close button
function closeWindow() {
    console.log('closeWindow function called');
    
    // Try various methods to close the window
    try {
        // Method 1: Standard window.close()
        if (window.close) {
            console.log('Trying window.close()');
            window.close();
        }
    } catch (e) {
        console.error('window.close() failed:', e);
    }
    
    // Method 2: History navigation for in-app browsers
    try {
        if (window.history && window.history.length > 1) {
            console.log('Trying history.back()');
            window.history.back();
        }
    } catch (e) {
        console.error('history.back() failed:', e);
    }
    
    // Method 3: Try going back in history with delay
    setTimeout(() => {
        if (!window.closed) {
            try {
                console.log('Trying history.go(-1)');
                window.history.go(-1);
            } catch (e) {
                console.error('history.go(-1) failed:', e);
            }
            
            // Method 4: For Android Chrome Custom Tabs, try to navigate to about:blank
            try {
                console.log('Trying to navigate to about:blank');
                window.location.href = 'about:blank';
            } catch (e) {
                console.error('Navigate to about:blank failed:', e);
            }
            
            // If nothing works, show a message
            setTimeout(() => {
                const container = document.querySelector('.container');
                if (container && !window.closed) {
                    console.log('All close methods failed, showing manual instruction');
                    container.innerHTML = `
                        <div class="icon success">✓</div>
                        <h1>Authentication Complete</h1>
                        <p>Please use the back button to return to the app.</p>
                    `;
                }
            }, 500);
        }
    }, 100);
}

// Attach event listener to close button when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    const closeBtn = document.getElementById('closeWindowBtn');
    if (closeBtn) {
        console.log('Close button found, attaching event listener');
        closeBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Close button clicked');
            closeWindow();
        });
    } else {
        console.log('Close button not found in DOM');
    }
});
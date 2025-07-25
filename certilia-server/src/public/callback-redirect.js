// Redirect-based callback for cross-origin scenarios
(function() {
    'use strict';
    
    // Extract data from DOM elements
    const success = document.getElementById('oauth-success')?.textContent === 'true';
    const code = document.getElementById('oauth-code')?.textContent || '';
    const state = document.getElementById('oauth-state')?.textContent || '';
    const error = document.getElementById('oauth-error')?.textContent || '';
    const errorDescription = document.getElementById('oauth-error-description')?.textContent || '';
    
    console.log('===== REDIRECT CALLBACK SCRIPT =====');
    console.log('Success:', success);
    console.log('Code:', code);
    console.log('State:', state);
    
    // Check if we have a return URL in sessionStorage
    const returnUrlKey = 'certilia_return_url';
    let returnUrl = null;
    
    try {
        returnUrl = sessionStorage.getItem(returnUrlKey);
        console.log('Return URL from sessionStorage:', returnUrl);
    } catch (e) {
        console.log('Could not access sessionStorage:', e);
    }
    
    // If no return URL, try to construct from referrer
    if (!returnUrl && document.referrer) {
        const referrerUrl = new URL(document.referrer);
        returnUrl = referrerUrl.origin;
        console.log('Using referrer as return URL:', returnUrl);
    }
    
    // Build callback data
    const callbackData = {
        success: success,
        code: code,
        state: state,
        error: error,
        errorDescription: errorDescription
    };
    
    // Option 1: If we have window.opener, try postMessage first
    if (window.opener && window.opener !== window) {
        console.log('Trying postMessage to opener');
        try {
            window.opener.postMessage(JSON.stringify({
                type: 'certilia_callback',
                ...callbackData
            }), '*');
            console.log('Message sent to opener');
            
            // Close window after short delay
            setTimeout(() => {
                window.close();
            }, 500);
            return;
        } catch (e) {
            console.error('postMessage failed:', e);
        }
    }
    
    // Option 2: Redirect with data in URL fragment
    if (returnUrl && success && code) {
        console.log('Redirecting with data in fragment');
        const redirectUrl = new URL(returnUrl);
        
        // Add data as URL fragment (doesn't get sent to server)
        const fragmentData = btoa(JSON.stringify(callbackData));
        redirectUrl.hash = `certilia-callback=${fragmentData}`;
        
        console.log('Redirecting to:', redirectUrl.toString());
        
        // Redirect after short delay to ensure logs are captured
        setTimeout(() => {
            window.location.href = redirectUrl.toString();
        }, 100);
    } else {
        console.log('Cannot redirect - missing return URL or authentication failed');
        // Just show the success/error page
    }
})();
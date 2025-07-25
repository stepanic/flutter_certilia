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
    
    // For polling approach - don't redirect, just close the window
    console.log('Polling approach - closing window after delay');
    console.log('Authentication result will be retrieved via polling');
    
    // Give user time to see the success message
    setTimeout(() => {
        console.log('Closing authentication window...');
        try {
            window.close();
        } catch (e) {
            console.log('Could not close window:', e);
            console.log('User may need to close manually');
        }
    }, 2000); // 2 second delay so user sees the success message
})();
// Alternative callback script using multiple communication methods
(function() {
    'use strict';
    
    // Extract data from DOM elements
    const success = document.getElementById('oauth-success')?.textContent === 'true';
    const code = document.getElementById('oauth-code')?.textContent || '';
    const state = document.getElementById('oauth-state')?.textContent || '';
    const error = document.getElementById('oauth-error')?.textContent || '';
    const errorDescription = document.getElementById('oauth-error-description')?.textContent || '';
    
    const callbackData = {
        type: 'certilia_callback',
        success: success,
        code: code,
        state: state,
        error: error,
        errorDescription: errorDescription,
        timestamp: Date.now()
    };
    
    console.log('===== ALTERNATIVE CALLBACK SCRIPT =====');
    console.log('Callback data:', callbackData);
    
    // Method 1: Try window.opener first
    if (window.opener && window.opener !== window) {
        console.log('Method 1: Using window.opener');
        try {
            window.opener.postMessage(JSON.stringify(callbackData), '*');
            console.log('Message sent via window.opener');
        } catch (e) {
            console.error('Failed to send via window.opener:', e);
        }
    }
    
    // Method 2: Use localStorage as fallback
    try {
        console.log('Method 2: Using localStorage');
        const storageKey = 'certilia_auth_callback';
        localStorage.setItem(storageKey, JSON.stringify(callbackData));
        console.log('Data saved to localStorage');
        
        // Also dispatch storage event
        window.dispatchEvent(new StorageEvent('storage', {
            key: storageKey,
            newValue: JSON.stringify(callbackData),
            url: window.location.href
        }));
    } catch (e) {
        console.error('Failed to use localStorage:', e);
    }
    
    // Method 3: Use BroadcastChannel if available
    if (typeof BroadcastChannel !== 'undefined') {
        try {
            console.log('Method 3: Using BroadcastChannel');
            const channel = new BroadcastChannel('certilia_auth_channel');
            channel.postMessage(callbackData);
            console.log('Message sent via BroadcastChannel');
            channel.close();
        } catch (e) {
            console.error('Failed to use BroadcastChannel:', e);
        }
    }
    
    // Method 4: Use custom event on window
    try {
        console.log('Method 4: Dispatching custom event');
        const event = new CustomEvent('certilia_auth_complete', {
            detail: callbackData,
            bubbles: true,
            cancelable: true
        });
        window.dispatchEvent(event);
        console.log('Custom event dispatched');
    } catch (e) {
        console.error('Failed to dispatch custom event:', e);
    }
    
    // Auto-close after a delay
    setTimeout(() => {
        console.log('Attempting to close window...');
        window.close();
    }, 1000);
})();
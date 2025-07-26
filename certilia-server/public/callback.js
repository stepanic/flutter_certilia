// Certilia OAuth Callback JavaScript
// This file handles the communication between the OAuth callback page and the parent window

(function() {
    'use strict';
    
    // Extract data from DOM elements
    const success = document.getElementById('oauth-success')?.textContent === 'true';
    const code = document.getElementById('oauth-code')?.textContent || '';
    const state = document.getElementById('oauth-state')?.textContent || '';
    const error = document.getElementById('oauth-error')?.textContent || '';
    const errorDescription = document.getElementById('oauth-error-description')?.textContent || '';
    
    // Enhanced debug logging
    console.log('===== CERTILIA CALLBACK SCRIPT LOADED =====');
    console.log('Page URL:', window.location.href);
    console.log('Extracted data:');
    console.log('  - Success:', success);
    console.log('  - Code:', code);
    console.log('  - State:', state);
    console.log('  - Error:', error);
    console.log('  - Error Description:', errorDescription);
    console.log('Window opener exists:', !!window.opener);
    console.log('Window opener same origin:', window.opener && window.opener !== window);
    
    // For mobile apps that use JavaScript interface
    if (window.OAuthCallback) {
        console.log('Mobile JavaScript interface detected');
        try {
            window.OAuthCallback.onComplete({
                success: success,
                code: code,
                state: state,
                error: error,
                errorDescription: errorDescription
            });
            console.log('Mobile callback completed');
        } catch (e) {
            console.error('Error calling mobile interface:', e);
        }
    }
    
    // For web platform - send message to opener window
    if (window.opener && window.opener !== window) {
        console.log('Opener window detected, preparing to send message');
        
        const message = {
            type: 'certilia_callback',
            success: success,
            code: code,
            state: state,
            error: error,
            errorDescription: errorDescription
        };
        
        console.log('Message to send:', message);
        
        // Set up fallback auto-close timer for web popups
        if (success) {
            console.log('Setting up fallback auto-close timer (3 seconds)');
            setTimeout(() => {
                if (!window.closed) {
                    console.log('Fallback: attempting to close popup window');
                    try {
                        window.close();
                    } catch (e) {
                        console.error('Fallback close failed:', e);
                    }
                }
            }, 3000);
        }
        
        // Function to send message with retries
        function sendMessage(attempt = 1) {
            console.log(`Sending message attempt ${attempt}...`);
            
            try {
                // Try multiple target origins
                const origins = [
                    '*', // Fallback to any origin
                    window.location.origin,
                    'http://localhost:3000',
                    'http://localhost:8080',
                    'http://localhost:5000',
                    'https://localhost:3000',
                    'https://localhost:8080',
                    'https://localhost:5000'
                ];
                
                let sent = false;
                for (const origin of origins) {
                    try {
                        console.log(`Attempting to send to origin: ${origin}`);
                        window.opener.postMessage(JSON.stringify(message), origin);
                        console.log(`Message sent successfully to ${origin}`);
                        sent = true;
                        break;
                    } catch (e) {
                        console.log(`Failed to send to ${origin}:`, e.message);
                    }
                }
                
                if (!sent && attempt < 3) {
                    console.log('All origins failed, retrying in 500ms...');
                    setTimeout(() => sendMessage(attempt + 1), 500);
                    return;
                }
                
                // Auto-close popup after sending message
                if (sent) {
                    console.log('Closing popup in 100ms...');
                    setTimeout(() => {
                        console.log('Attempting to close window...');
                        window.close();
                    }, 100);
                }
            } catch (e) {
                console.error('Failed to send message to opener:', e);
                if (attempt < 3) {
                    console.log('Retrying in 500ms...');
                    setTimeout(() => sendMessage(attempt + 1), 500);
                }
            }
        }
        
        // Send message with small delay to ensure everything is loaded
        setTimeout(() => {
            sendMessage();
        }, 100);
    } else {
        console.log('No opener window detected');
        console.log('window.opener:', window.opener);
        console.log('window:', window);
        console.log('Is same window:', window.opener === window);
    }
    
    // For apps using deep links
    const deepLinkElement = document.getElementById('deep-link');
    const deepLink = deepLinkElement?.textContent || deepLinkElement?.getAttribute('data-link');
    
    if (deepLink && deepLink !== 'null' && deepLink !== '') {
        console.log('Deep link detected:', deepLink);
        setTimeout(() => {
            console.log('Redirecting to deep link...');
            window.location.href = deepLink;
        }, 1000);
    }
    
    // Additional debugging - log all window properties
    console.log('===== WINDOW DEBUGGING =====');
    try {
        console.log('Window name:', window.name);
        console.log('Window location:', window.location.href);
        console.log('Document referrer:', document.referrer);
        console.log('Parent window same:', window.parent === window);
        console.log('Top window same:', window.top === window);
    } catch (e) {
        console.error('Error accessing window properties:', e);
    }
    
    // Auto-close window for polling approach
    if (!window.opener || window.opener === window) {
        console.log('No opener detected - using polling approach');
        console.log('Window will close automatically in 3 seconds...');
        
        setTimeout(() => {
            console.log('Attempting to close window...');
            try {
                window.close();
            } catch (e) {
                console.error('Could not close window:', e);
                console.log('User may need to close this window manually');
            }
        }, 3000);
    }
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
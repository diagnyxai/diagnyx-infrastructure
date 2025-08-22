const https = require('https');

/**
 * Lambda function triggered after user confirms their email address in Cognito
 * This function activates the user in our application database
 */
exports.handler = async (event, context) => {
    console.log('Post-confirmation Lambda triggered:', JSON.stringify(event, null, 2));
    
    const { triggerSource, userPoolId, userName, request, response } = event;
    const userAttributes = request.userAttributes;
    
    // Only process post-confirmation events
    if (triggerSource === 'PostConfirmation_ConfirmSignUp' || triggerSource === 'PostConfirmation_ConfirmForgotPassword') {
        try {
            // Extract user information
            const userData = {
                cognitoSub: userAttributes.sub,
                email: userAttributes.email,
                firstName: userAttributes.given_name,
                lastName: userAttributes.family_name,
                accountType: userAttributes['custom:account_type'] || 'INDIVIDUAL',
                organizationId: userAttributes['custom:organization_id'] || null
            };
            
            console.log('Activating user:', userData);
            
            // Call user service to activate the user
            await activateUser(userData);
            
            console.log('User activation successful');
            
        } catch (error) {
            console.error('Error in post-confirmation trigger:', error);
            // Don't throw error to avoid disrupting user experience
            // Log the error and continue
        }
    }
    
    // Return the event unchanged
    return event;
};

/**
 * Call the user service to activate the user
 */
async function activateUser(userData) {
    const apiEndpoint = process.env.API_ENDPOINT || 'http://localhost:8443';
    const internalApiKey = process.env.INTERNAL_API_KEY;
    
    const payload = {
        action: 'activateUser',
        data: userData
    };
    
    const postData = JSON.stringify(payload);
    
    const options = {
        hostname: new URL(apiEndpoint).hostname,
        port: new URL(apiEndpoint).port || (apiEndpoint.includes('https') ? 443 : 80),
        path: '/api/v1/internal/user/activate',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData),
            'X-Internal-API-Key': internalApiKey || 'dev-internal-key',
            'User-Agent': 'Cognito-PostConfirmation-Lambda'
        }
    };
    
    return new Promise((resolve, reject) => {
        const protocol = apiEndpoint.includes('https') ? https : require('http');
        
        const req = protocol.request(options, (res) => {
            let body = '';
            
            res.on('data', (chunk) => {
                body += chunk;
            });
            
            res.on('end', () => {
                console.log('User service response:', res.statusCode, body);
                
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(JSON.parse(body || '{}'));
                } else {
                    reject(new Error(`User service error: ${res.statusCode} ${body}`));
                }
            });
        });
        
        req.on('error', (error) => {
            console.error('Request error:', error);
            reject(error);
        });
        
        // Set timeout
        req.setTimeout(10000, () => {
            req.destroy();
            reject(new Error('Request timeout'));
        });
        
        req.write(postData);
        req.end();
    });
}
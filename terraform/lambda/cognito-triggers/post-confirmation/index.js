const https = require('https');

// Environment variables
const API_ENDPOINT = process.env.API_ENDPOINT || 'https://api.diagnyx.ai';
const INTERNAL_API_KEY = process.env.INTERNAL_API_KEY;

/**
 * Lambda function triggered after Cognito user confirmation
 * Activates the user in the application database
 */
exports.handler = async (event, context) => {
    console.log('Post confirmation trigger event:', JSON.stringify(event, null, 2));
    
    const { triggerSource, userPoolId, userName } = event;
    const userAttributes = event.request.userAttributes;
    
    // Only process confirmation events
    if (triggerSource === 'PostConfirmation_ConfirmSignUp' || 
        triggerSource === 'PostConfirmation_ConfirmForgotPassword') {
        
        try {
            // Activate user in our database
            await activateUser({
                cognitoSub: userAttributes.sub,
                email: userAttributes.email,
                firstName: userAttributes.given_name,
                lastName: userAttributes.family_name,
                accountType: userAttributes['custom:account_type'],
                organizationId: userAttributes['custom:organization_id']
            });
            
            console.log(`User ${userAttributes.email} activated successfully`);
        } catch (error) {
            console.error('Error activating user:', error);
            // Don't fail the confirmation process - user can still login
            // Application will handle incomplete activation scenarios
        }
    }
    
    return event;
};

/**
 * Activates user in the application database via internal API
 */
async function activateUser(userData) {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify({
            cognitoSub: userData.cognitoSub,
            email: userData.email,
            firstName: userData.firstName,
            lastName: userData.lastName,
            accountType: userData.accountType,
            organizationId: userData.organizationId
        });
        
        const url = new URL(API_ENDPOINT);
        const options = {
            hostname: url.hostname,
            port: url.port || 443,
            path: '/internal/users/activate',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData),
                'X-Internal-Key': INTERNAL_API_KEY,
                'User-Agent': 'Diagnyx-Lambda-PostConfirmation'
            },
            timeout: 10000 // 10 second timeout
        };
        
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                console.log(`API Response Status: ${res.statusCode}`);
                console.log(`API Response Body: ${data}`);
                
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(data);
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                }
            });
        });
        
        req.on('error', (error) => {
            console.error('Request error:', error);
            reject(error);
        });
        
        req.on('timeout', () => {
            req.destroy();
            reject(new Error('Request timeout'));
        });
        
        req.write(postData);
        req.end();
    });
}
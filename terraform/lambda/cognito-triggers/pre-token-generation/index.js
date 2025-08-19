const https = require('https');

// Environment variables
const API_ENDPOINT = process.env.API_ENDPOINT || 'https://api.diagnyx.ai';
const INTERNAL_API_KEY = process.env.INTERNAL_API_KEY;

/**
 * Lambda function triggered before JWT token generation
 * Adds custom claims to the JWT token based on user data from database
 */
exports.handler = async (event, context) => {
    console.log('Pre token generation event:', JSON.stringify(event, null, 2));
    
    const { triggerSource, userPoolId, userName } = event;
    const userAttributes = event.request.userAttributes;
    
    try {
        // Fetch user data from our database to get current role and organization info
        const userData = await fetchUserData(userAttributes.sub);
        
        if (userData) {
            // Add custom claims to the token
            event.response = {
                claimsOverrideDetails: {
                    claimsToAddOrOverride: {
                        'custom:role': userData.role,
                        'custom:organization_id': userData.organizationId,
                        'custom:organization_name': userData.organizationName,
                        'custom:account_type': userData.accountType,
                        'custom:permissions': JSON.stringify(userData.permissions || []),
                        'custom:teams': JSON.stringify(userData.teams || [])
                    }
                }
            };
            
            console.log(`Custom claims added for user: ${userAttributes.email}`);
        } else {
            console.warn(`No user data found for Cognito sub: ${userAttributes.sub}`);
        }
        
    } catch (error) {
        console.error('Error fetching user data:', error);
        // Don't fail token generation, just skip custom claims
        // User will still get basic authentication but may need to refresh for full permissions
    }
    
    return event;
};

/**
 * Fetches user data from the application database via internal API
 */
async function fetchUserData(cognitoSub) {
    return new Promise((resolve, reject) => {
        const url = new URL(API_ENDPOINT);
        const options = {
            hostname: url.hostname,
            port: url.port || 443,
            path: `/internal/users/cognito/${encodeURIComponent(cognitoSub)}`,
            method: 'GET',
            headers: {
                'X-Internal-Key': INTERNAL_API_KEY,
                'User-Agent': 'Diagnyx-Lambda-PreTokenGeneration',
                'Accept': 'application/json'
            },
            timeout: 5000 // 5 second timeout
        };
        
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                console.log(`API Response Status: ${res.statusCode}`);
                
                if (res.statusCode === 200) {
                    try {
                        const userData = JSON.parse(data);
                        resolve(userData);
                    } catch (parseError) {
                        console.error('Error parsing user data:', parseError);
                        resolve(null);
                    }
                } else if (res.statusCode === 404) {
                    console.log('User not found in database');
                    resolve(null);
                } else {
                    console.error(`API Error: ${res.statusCode} - ${data}`);
                    resolve(null);
                }
            });
        });
        
        req.on('error', (error) => {
            console.error('Request error:', error);
            resolve(null); // Don't reject to avoid breaking token generation
        });
        
        req.on('timeout', () => {
            req.destroy();
            console.error('Request timeout');
            resolve(null);
        });
        
        req.end();
    });
}
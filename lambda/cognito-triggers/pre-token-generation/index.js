/**
 * Lambda function triggered before token generation in Cognito
 * This function adds custom claims to the JWT token
 */
exports.handler = async (event, context) => {
    console.log('Pre-token generation Lambda triggered:', JSON.stringify(event, null, 2));
    
    const { triggerSource, userPoolId, userName, request, response } = event;
    const userAttributes = request.userAttributes;
    
    try {
        // Add custom claims to the ID token
        if (!response.claimsOverrideDetails) {
            response.claimsOverrideDetails = {};
        }
        
        if (!response.claimsOverrideDetails.claimsToAddOrOverride) {
            response.claimsOverrideDetails.claimsToAddOrOverride = {};
        }
        
        // Add account type to claims
        if (userAttributes['custom:account_type']) {
            response.claimsOverrideDetails.claimsToAddOrOverride['account_type'] = userAttributes['custom:account_type'];
        }
        
        // Add organization ID to claims if available
        if (userAttributes['custom:organization_id']) {
            response.claimsOverrideDetails.claimsToAddOrOverride['organization_id'] = userAttributes['custom:organization_id'];
        }
        
        // Add user role if available (this might be fetched from database in production)
        const userRole = await getUserRole(userAttributes.sub);
        if (userRole) {
            response.claimsOverrideDetails.claimsToAddOrOverride['role'] = userRole;
        }
        
        // Add custom scope for API access
        response.claimsOverrideDetails.claimsToAddOrOverride['scope'] = getCustomScope(userAttributes);
        
        // Add environment info
        response.claimsOverrideDetails.claimsToAddOrOverride['environment'] = process.env.ENVIRONMENT || 'dev';
        
        console.log('Added custom claims:', response.claimsOverrideDetails.claimsToAddOrOverride);
        
    } catch (error) {
        console.error('Error in pre-token generation:', error);
        // Don't throw error to avoid disrupting user authentication
    }
    
    return event;
};

/**
 * Get user role from database (simplified for local development)
 */
async function getUserRole(cognitoSub) {
    try {
        // In production, this would query the database
        // For local development, return default role
        console.log('Getting user role for:', cognitoSub);
        
        // TODO: Implement database query when RDS is available
        // For now, return default role based on account type
        return 'OWNER'; // Default role for account owners
        
    } catch (error) {
        console.error('Error getting user role:', error);
        return null;
    }
}

/**
 * Generate custom scope based on user attributes
 */
function getCustomScope(userAttributes) {
    const accountType = userAttributes['custom:account_type'] || 'INDIVIDUAL';
    
    const baseScopes = ['read:profile', 'write:profile'];
    
    switch (accountType) {
        case 'INDIVIDUAL':
            return [...baseScopes, 'read:individual_data', 'write:individual_data'].join(' ');
        case 'TEAM':
            return [...baseScopes, 'read:team_data', 'write:team_data', 'manage:team'].join(' ');
        case 'ENTERPRISE':
            return [...baseScopes, 'read:enterprise_data', 'write:enterprise_data', 'manage:organization', 'admin:all'].join(' ');
        default:
            return baseScopes.join(' ');
    }
}
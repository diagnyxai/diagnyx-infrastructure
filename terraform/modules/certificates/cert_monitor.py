"""
AWS Lambda function to monitor SSL certificate expiry dates
Sends notifications when certificates are approaching expiry
"""

import json
import boto3
import datetime
from typing import Dict, Any, Optional

# Initialize AWS clients
acm_client = boto3.client('acm')
sns_client = boto3.client('sns')


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for certificate expiry monitoring
    
    Args:
        event: Lambda event data
        context: Lambda context object
        
    Returns:
        Response dictionary with status and details
    """
    
    try:
        # Get environment variables
        certificate_arn = event.get('certificate_arn') or context.environment.get('CERTIFICATE_ARN')
        sns_topic_arn = context.environment.get('SNS_TOPIC_ARN')
        environment = context.environment.get('ENVIRONMENT', '${environment}')
        
        if not certificate_arn:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Certificate ARN not provided',
                    'message': 'CERTIFICATE_ARN environment variable or event parameter required'
                })
            }
        
        # Check certificate expiry
        cert_details = get_certificate_details(certificate_arn)
        if not cert_details:
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': 'Certificate not found',
                    'certificate_arn': certificate_arn
                })
            }
        
        # Calculate days until expiry
        days_until_expiry = calculate_days_until_expiry(cert_details['NotAfter'])
        
        # Determine if notification is needed
        warning_thresholds = [30, 14, 7, 3, 1]  # Days before expiry to warn
        should_notify = days_until_expiry in warning_thresholds or days_until_expiry <= 0
        
        response_data = {
            'certificate_arn': certificate_arn,
            'domain_name': cert_details['DomainName'],
            'subject_alternative_names': cert_details.get('SubjectAlternativeNames', []),
            'status': cert_details['Status'],
            'not_after': cert_details['NotAfter'].isoformat(),
            'days_until_expiry': days_until_expiry,
            'notification_sent': False,
            'environment': environment
        }
        
        # Send notification if needed
        if should_notify and sns_topic_arn:
            notification_sent = send_expiry_notification(
                sns_topic_arn, 
                cert_details, 
                days_until_expiry, 
                environment
            )
            response_data['notification_sent'] = notification_sent
        
        # Log the check result
        print(f"Certificate check completed: {json.dumps(response_data, default=str)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(response_data, default=str)
        }
        
    except Exception as e:
        error_msg = f"Error monitoring certificate: {str(e)}"
        print(error_msg)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal error',
                'message': error_msg,
                'certificate_arn': certificate_arn if 'certificate_arn' in locals() else 'unknown'
            })
        }


def get_certificate_details(certificate_arn: str) -> Optional[Dict[str, Any]]:
    """
    Retrieve certificate details from ACM
    
    Args:
        certificate_arn: ARN of the certificate to check
        
    Returns:
        Certificate details dictionary or None if not found
    """
    
    try:
        response = acm_client.describe_certificate(CertificateArn=certificate_arn)
        return response['Certificate']
    except acm_client.exceptions.ResourceNotFoundException:
        print(f"Certificate not found: {certificate_arn}")
        return None
    except Exception as e:
        print(f"Error retrieving certificate details: {str(e)}")
        return None


def calculate_days_until_expiry(not_after: datetime.datetime) -> int:
    """
    Calculate number of days until certificate expires
    
    Args:
        not_after: Certificate expiry datetime
        
    Returns:
        Number of days until expiry (negative if already expired)
    """
    
    now = datetime.datetime.now(datetime.timezone.utc)
    
    # Ensure not_after is timezone-aware
    if not_after.tzinfo is None:
        not_after = not_after.replace(tzinfo=datetime.timezone.utc)
    
    time_diff = not_after - now
    return time_diff.days


def send_expiry_notification(
    sns_topic_arn: str, 
    cert_details: Dict[str, Any], 
    days_until_expiry: int,
    environment: str
) -> bool:
    """
    Send certificate expiry notification via SNS
    
    Args:
        sns_topic_arn: SNS topic ARN for notifications
        cert_details: Certificate details dictionary
        days_until_expiry: Number of days until certificate expires
        environment: Environment name
        
    Returns:
        True if notification sent successfully, False otherwise
    """
    
    try:
        # Determine urgency level
        if days_until_expiry <= 0:
            urgency = "🔴 EXPIRED"
            action_required = "IMMEDIATE ACTION REQUIRED - Certificate has expired"
        elif days_until_expiry <= 3:
            urgency = "🟠 CRITICAL"
            action_required = "URGENT ACTION REQUIRED - Certificate expires very soon"
        elif days_until_expiry <= 7:
            urgency = "🟡 WARNING"
            action_required = "ACTION REQUIRED - Certificate expires soon"
        else:
            urgency = "🔵 INFO"
            action_required = "Plan certificate renewal"
        
        # Create notification message
        subject = f"{urgency} SSL Certificate Expiry Alert - {environment.upper()}"
        
        message = f"""
SSL Certificate Expiry Notification
Environment: {environment.upper()}
Urgency: {urgency}

CERTIFICATE DETAILS:
• Domain: {cert_details['DomainName']}
• Alternative Names: {', '.join(cert_details.get('SubjectAlternativeNames', []))}
• Status: {cert_details['Status']}
• Expires: {cert_details['NotAfter'].strftime('%Y-%m-%d %H:%M:%S UTC')}
• Days Until Expiry: {days_until_expiry}

{action_required}

NEXT STEPS:
1. Verify certificate auto-renewal is configured
2. If manual renewal required, request new certificate
3. Update load balancer/CloudFront distributions
4. Test SSL configuration after renewal

Certificate ARN: {cert_details.get('CertificateArn', 'N/A')}

This is an automated notification from the Diagnyx SSL monitoring system.
Environment: {environment}
Timestamp: {datetime.datetime.now(datetime.timezone.utc).isoformat()}
        """.strip()
        
        # Send SNS notification
        response = sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=message,
            MessageAttributes={
                'environment': {
                    'DataType': 'String',
                    'StringValue': environment
                },
                'urgency': {
                    'DataType': 'String',
                    'StringValue': urgency.split()[0]  # Remove emoji for filtering
                },
                'days_until_expiry': {
                    'DataType': 'Number',
                    'StringValue': str(days_until_expiry)
                },
                'certificate_domain': {
                    'DataType': 'String',
                    'StringValue': cert_details['DomainName']
                }
            }
        )
        
        print(f"Notification sent successfully. MessageId: {response['MessageId']}")
        return True
        
    except Exception as e:
        print(f"Error sending notification: {str(e)}")
        return False


# For local testing
if __name__ == "__main__":
    # Test event
    test_event = {
        'certificate_arn': 'arn:aws:acm:us-east-1:123456789012:certificate/test-cert-id'
    }
    
    # Mock context
    class MockContext:
        def __init__(self):
            self.environment = {
                'CERTIFICATE_ARN': 'arn:aws:acm:us-east-1:123456789012:certificate/test-cert-id',
                'SNS_TOPIC_ARN': 'arn:aws:sns:us-east-1:123456789012:test-topic',
                'ENVIRONMENT': 'dev'
            }
    
    result = handler(test_event, MockContext())
    print(json.dumps(result, indent=2))
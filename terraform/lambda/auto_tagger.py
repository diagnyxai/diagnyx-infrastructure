"""
Auto Tagger Lambda Function
Automatically tags resources created without proper tags for cost tracking
"""

import os
import json
import boto3
import logging
from datetime import datetime

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')
s3_client = boto3.client('s3')

def handler(event, context):
    """
    Main Lambda handler for auto-tagging resources
    """
    try:
        # Get default tags from environment
        default_tags = json.loads(os.environ.get('DEFAULT_TAGS', '{}'))
        
        # Add dynamic tags
        default_tags['LastModified'] = datetime.utcnow().isoformat()
        default_tags['AutoTagged'] = 'true'
        
        # Determine resource type from event
        source = event.get('source', '')
        detail_type = event.get('detail-type', '')
        detail = event.get('detail', {})
        
        logger.info(f"Processing event from {source}: {detail_type}")
        
        if source == 'aws.ec2':
            handle_ec2_event(detail, default_tags)
        elif source == 'aws.rds':
            handle_rds_event(detail, default_tags)
        elif source == 'aws.s3':
            handle_s3_event(detail, default_tags)
        else:
            logger.warning(f"Unsupported event source: {source}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Tags applied successfully',
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error in auto-tagging: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def handle_ec2_event(detail, default_tags):
    """
    Handle EC2 instance tagging
    """
    instance_id = detail.get('instance-id')
    if not instance_id:
        return
    
    # Check existing tags
    response = ec2_client.describe_instances(InstanceIds=[instance_id])
    if not response['Reservations']:
        return
    
    instance = response['Reservations'][0]['Instances'][0]
    existing_tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
    
    # Determine which tags are missing
    tags_to_add = []
    for key, value in default_tags.items():
        if key not in existing_tags:
            tags_to_add.append({'Key': key, 'Value': str(value)})
    
    if tags_to_add:
        logger.info(f"Adding {len(tags_to_add)} tags to EC2 instance {instance_id}")
        
        # Add instance-specific tags
        tags_to_add.append({'Key': 'InstanceType', 'Value': instance['InstanceType']})
        tags_to_add.append({'Key': 'LaunchTime', 'Value': instance['LaunchTime'].isoformat()})
        
        # Determine cost optimization tags
        if instance['InstanceLifecycleType'] == 'spot':
            tags_to_add.append({'Key': 'CostOptimized', 'Value': 'spot-instance'})
        
        ec2_client.create_tags(
            Resources=[instance_id],
            Tags=tags_to_add
        )
        
        # Also tag associated volumes
        for volume in instance.get('BlockDeviceMappings', []):
            if 'Ebs' in volume:
                volume_id = volume['Ebs']['VolumeId']
                ec2_client.create_tags(
                    Resources=[volume_id],
                    Tags=tags_to_add + [{'Key': 'AttachedInstance', 'Value': instance_id}]
                )

def handle_rds_event(detail, default_tags):
    """
    Handle RDS instance tagging
    """
    db_instance_id = detail.get('SourceIdentifier')
    if not db_instance_id:
        return
    
    try:
        # Get DB instance details
        response = rds_client.describe_db_instances(DBInstanceIdentifier=db_instance_id)
        if not response['DBInstances']:
            return
        
        db_instance = response['DBInstances'][0]
        db_arn = db_instance['DBInstanceArn']
        
        # Get existing tags
        tags_response = rds_client.list_tags_for_resource(ResourceName=db_arn)
        existing_tags = {tag['Key']: tag['Value'] for tag in tags_response['TagList']}
        
        # Determine which tags are missing
        tags_to_add = []
        for key, value in default_tags.items():
            if key not in existing_tags:
                tags_to_add.append({'Key': key, 'Value': str(value)})
        
        if tags_to_add:
            logger.info(f"Adding {len(tags_to_add)} tags to RDS instance {db_instance_id}")
            
            # Add RDS-specific tags
            tags_to_add.append({'Key': 'Engine', 'Value': db_instance['Engine']})
            tags_to_add.append({'Key': 'InstanceClass', 'Value': db_instance['DBInstanceClass']})
            tags_to_add.append({'Key': 'MultiAZ', 'Value': str(db_instance['MultiAZ'])})
            
            rds_client.add_tags_to_resource(
                ResourceName=db_arn,
                Tags=tags_to_add
            )
            
    except Exception as e:
        logger.error(f"Error tagging RDS instance {db_instance_id}: {str(e)}")

def handle_s3_event(detail, default_tags):
    """
    Handle S3 bucket tagging
    """
    bucket_name = detail.get('bucket', {}).get('name')
    if not bucket_name:
        return
    
    try:
        # Get existing tags
        try:
            response = s3_client.get_bucket_tagging(Bucket=bucket_name)
            existing_tags = {tag['Key']: tag['Value'] for tag in response.get('TagSet', [])}
        except s3_client.exceptions.NoSuchTagSet:
            existing_tags = {}
        
        # Merge with default tags
        all_tags = {**default_tags, **existing_tags}
        
        # Add S3-specific tags
        all_tags['StorageClass'] = 'STANDARD'
        all_tags['BucketPurpose'] = determine_bucket_purpose(bucket_name)
        
        # Convert to TagSet format
        tag_set = [{'Key': k, 'Value': str(v)} for k, v in all_tags.items()]
        
        logger.info(f"Updating tags for S3 bucket {bucket_name}")
        s3_client.put_bucket_tagging(
            Bucket=bucket_name,
            Tagging={'TagSet': tag_set}
        )
        
        # Also set up lifecycle policy if it's a log bucket
        if 'log' in bucket_name.lower():
            setup_log_bucket_lifecycle(bucket_name)
            
    except Exception as e:
        logger.error(f"Error tagging S3 bucket {bucket_name}: {str(e)}")

def determine_bucket_purpose(bucket_name):
    """
    Determine bucket purpose based on naming convention
    """
    name_lower = bucket_name.lower()
    
    if 'log' in name_lower:
        return 'logging'
    elif 'backup' in name_lower:
        return 'backup'
    elif 'static' in name_lower or 'asset' in name_lower:
        return 'static-content'
    elif 'metric' in name_lower or 'analytic' in name_lower:
        return 'analytics'
    elif 'temp' in name_lower or 'tmp' in name_lower:
        return 'temporary'
    else:
        return 'general'

def setup_log_bucket_lifecycle(bucket_name):
    """
    Set up lifecycle policy for log buckets to optimize costs
    """
    try:
        s3_client.put_bucket_lifecycle_configuration(
            Bucket=bucket_name,
            LifecycleConfiguration={
                'Rules': [
                    {
                        'ID': 'auto-archive-logs',
                        'Status': 'Enabled',
                        'Transitions': [
                            {
                                'Days': 30,
                                'StorageClass': 'STANDARD_IA'
                            },
                            {
                                'Days': 90,
                                'StorageClass': 'GLACIER'
                            }
                        ],
                        'Expiration': {
                            'Days': 365
                        }
                    }
                ]
            }
        )
        logger.info(f"Lifecycle policy applied to log bucket {bucket_name}")
    except Exception as e:
        logger.warning(f"Could not apply lifecycle policy to {bucket_name}: {str(e)}")
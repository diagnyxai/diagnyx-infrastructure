"""
Scheduled Scaling Lambda Function
Automatically scales EKS node groups based on schedule for cost optimization
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
eks_client = boto3.client('eks')
autoscaling_client = boto3.client('autoscaling')

def handler(event, context):
    """
    Main Lambda handler for scheduled scaling
    """
    try:
        # Get environment variables
        cluster_name = os.environ['CLUSTER_NAME']
        environment = os.environ['ENVIRONMENT']
        
        # Determine action from event
        action = event.get('action', 'scale_down')
        
        logger.info(f"Executing {action} for cluster {cluster_name} in {environment}")
        
        if action == 'scale_down':
            scale_down(cluster_name)
        elif action == 'scale_up':
            scale_up(cluster_name)
        else:
            raise ValueError(f"Unknown action: {action}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f"Successfully executed {action}",
                'cluster': cluster_name,
                'environment': environment,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error during scaling operation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def scale_down(cluster_name):
    """
    Scale down node groups to minimum capacity
    """
    min_nodes = int(os.environ.get('MIN_NODES_OFF', '0'))
    desired_nodes = int(os.environ.get('DESIRED_NODES_OFF', '0'))
    
    # List all node groups
    response = eks_client.list_nodegroups(clusterName=cluster_name)
    node_groups = response['nodegroups']
    
    for node_group in node_groups:
        # Skip monitoring node group
        if 'monitoring' in node_group.lower():
            logger.info(f"Skipping monitoring node group: {node_group}")
            continue
        
        try:
            # Update node group configuration
            logger.info(f"Scaling down node group {node_group} to {desired_nodes} nodes")
            
            eks_client.update_nodegroup_config(
                clusterName=cluster_name,
                nodegroupName=node_group,
                scalingConfig={
                    'minSize': min_nodes,
                    'desiredSize': desired_nodes
                }
            )
            
            logger.info(f"Successfully scaled down {node_group}")
            
        except Exception as e:
            logger.error(f"Failed to scale down {node_group}: {str(e)}")
    
    # Also scale down RDS if configured
    scale_rds('stop')
    
    # Scale down ElastiCache if configured
    scale_elasticache('decrease')

def scale_up(cluster_name):
    """
    Scale up node groups to normal capacity
    """
    min_nodes = int(os.environ.get('MIN_NODES_ON', '1'))
    desired_nodes = int(os.environ.get('DESIRED_NODES_ON', '2'))
    
    # List all node groups
    response = eks_client.list_nodegroups(clusterName=cluster_name)
    node_groups = response['nodegroups']
    
    for node_group in node_groups:
        # Skip monitoring node group (keep it running)
        if 'monitoring' in node_group.lower():
            continue
        
        try:
            # Update node group configuration
            logger.info(f"Scaling up node group {node_group} to {desired_nodes} nodes")
            
            eks_client.update_nodegroup_config(
                clusterName=cluster_name,
                nodegroupName=node_group,
                scalingConfig={
                    'minSize': min_nodes,
                    'desiredSize': desired_nodes
                }
            )
            
            logger.info(f"Successfully scaled up {node_group}")
            
        except Exception as e:
            logger.error(f"Failed to scale up {node_group}: {str(e)}")
    
    # Also scale up RDS if configured
    scale_rds('start')
    
    # Scale up ElastiCache if configured
    scale_elasticache('increase')

def scale_rds(action):
    """
    Start or stop RDS instances for cost optimization
    """
    try:
        rds_client = boto3.client('rds')
        environment = os.environ['ENVIRONMENT']
        
        # List RDS instances with environment tag
        response = rds_client.describe_db_instances()
        
        for db in response['DBInstances']:
            # Check if instance belongs to this environment
            tags_response = rds_client.list_tags_for_resource(
                ResourceName=db['DBInstanceArn']
            )
            
            env_tag = next(
                (tag for tag in tags_response['TagList'] 
                 if tag['Key'] == 'Environment' and tag['Value'] == environment),
                None
            )
            
            if not env_tag:
                continue
            
            db_identifier = db['DBInstanceIdentifier']
            
            if action == 'stop' and db['DBInstanceStatus'] == 'available':
                logger.info(f"Stopping RDS instance {db_identifier}")
                rds_client.stop_db_instance(DBInstanceIdentifier=db_identifier)
                
            elif action == 'start' and db['DBInstanceStatus'] == 'stopped':
                logger.info(f"Starting RDS instance {db_identifier}")
                rds_client.start_db_instance(DBInstanceIdentifier=db_identifier)
                
    except Exception as e:
        logger.warning(f"RDS scaling operation failed: {str(e)}")

def scale_elasticache(action):
    """
    Scale ElastiCache clusters for cost optimization
    """
    try:
        elasticache_client = boto3.client('elasticache')
        environment = os.environ['ENVIRONMENT']
        
        # List cache clusters
        response = elasticache_client.describe_cache_clusters()
        
        for cluster in response['CacheClusters']:
            cluster_id = cluster['CacheClusterId']
            
            # Check if cluster belongs to this environment
            if environment not in cluster_id.lower():
                continue
            
            if action == 'decrease':
                # Scale down to 1 node for dev/staging
                logger.info(f"Scaling down ElastiCache cluster {cluster_id}")
                # Note: Modifying node count requires specific API based on cluster type
                
            elif action == 'increase':
                # Scale up to normal capacity
                logger.info(f"Scaling up ElastiCache cluster {cluster_id}")
                
    except Exception as e:
        logger.warning(f"ElastiCache scaling operation failed: {str(e)}")

def send_notification(message):
    """
    Send SNS notification about scaling event
    """
    try:
        sns_topic = os.environ.get('SNS_TOPIC_ARN')
        if sns_topic:
            sns_client = boto3.client('sns')
            sns_client.publish(
                TopicArn=sns_topic,
                Subject=f"Scheduled Scaling Event - {os.environ['ENVIRONMENT']}",
                Message=message
            )
    except Exception as e:
        logger.warning(f"Failed to send notification: {str(e)}")
"""
Cost Optimizer Lambda Function
Analyzes AWS resources and provides cost optimization recommendations
"""

import os
import json
import boto3
import logging
from datetime import datetime, timedelta
from collections import defaultdict

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ce_client = boto3.client('ce')
ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')
cloudwatch_client = boto3.client('cloudwatch')
sns_client = boto3.client('sns')

def handler(event, context):
    """
    Main Lambda handler for cost optimization analysis
    """
    try:
        environment = os.environ.get('ENVIRONMENT', 'unknown')
        recommendations = []
        
        logger.info(f"Starting cost optimization analysis for {environment}")
        
        # Analyze different resource types
        recommendations.extend(analyze_ec2_instances())
        recommendations.extend(analyze_rds_instances())
        recommendations.extend(analyze_ebs_volumes())
        recommendations.extend(analyze_elastic_ips())
        recommendations.extend(analyze_nat_gateways())
        recommendations.extend(analyze_old_snapshots())
        recommendations.extend(analyze_reserved_instances())
        
        # Get cost trends
        cost_analysis = analyze_cost_trends()
        
        # Generate report
        report = generate_report(recommendations, cost_analysis)
        
        # Send notification if recommendations found
        if recommendations:
            send_notification(report)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cost optimization analysis completed',
                'recommendations_count': len(recommendations),
                'potential_savings': calculate_total_savings(recommendations),
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error in cost optimization analysis: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def analyze_ec2_instances():
    """
    Analyze EC2 instances for optimization opportunities
    """
    recommendations = []
    threshold_cpu = float(os.environ.get('THRESHOLD_UNDERUTILIZED', '30'))
    
    try:
        # Get all running instances
        response = ec2_client.describe_instances(
            Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                instance_type = instance['InstanceType']
                
                # Check CPU utilization
                cpu_stats = get_cpu_utilization(instance_id)
                
                if cpu_stats and cpu_stats['average'] < threshold_cpu:
                    savings = estimate_downsize_savings(instance_type)
                    recommendations.append({
                        'type': 'EC2_UNDERUTILIZED',
                        'resource_id': instance_id,
                        'current_type': instance_type,
                        'recommendation': f"Downsize from {instance_type} (CPU avg: {cpu_stats['average']:.1f}%)",
                        'estimated_savings': savings
                    })
                
                # Check for instances without reserved capacity
                if instance.get('InstanceLifecycle') != 'spot':
                    tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
                    if tags.get('Environment') == 'production':
                        recommendations.append({
                            'type': 'EC2_NO_RESERVATION',
                            'resource_id': instance_id,
                            'current_type': instance_type,
                            'recommendation': 'Consider Reserved Instance or Savings Plan',
                            'estimated_savings': estimate_reservation_savings(instance_type)
                        })
                
    except Exception as e:
        logger.error(f"Error analyzing EC2 instances: {str(e)}")
    
    return recommendations

def analyze_rds_instances():
    """
    Analyze RDS instances for optimization
    """
    recommendations = []
    
    try:
        response = rds_client.describe_db_instances()
        
        for db in response['DBInstances']:
            db_id = db['DBInstanceIdentifier']
            db_class = db['DBInstanceClass']
            
            # Check connection count
            connection_stats = get_rds_connections(db_id)
            
            if connection_stats and connection_stats['max'] < 10:
                recommendations.append({
                    'type': 'RDS_UNDERUTILIZED',
                    'resource_id': db_id,
                    'current_type': db_class,
                    'recommendation': f"Downsize RDS instance (max connections: {connection_stats['max']})",
                    'estimated_savings': estimate_rds_downsize_savings(db_class)
                })
            
            # Check for Multi-AZ in non-production
            if db['MultiAZ']:
                tags = rds_client.list_tags_for_resource(ResourceName=db['DBInstanceArn'])
                tag_dict = {tag['Key']: tag['Value'] for tag in tags['TagList']}
                if tag_dict.get('Environment') != 'production':
                    recommendations.append({
                        'type': 'RDS_UNNECESSARY_MULTI_AZ',
                        'resource_id': db_id,
                        'recommendation': 'Disable Multi-AZ for non-production',
                        'estimated_savings': estimate_multi_az_savings(db_class)
                    })
                    
    except Exception as e:
        logger.error(f"Error analyzing RDS instances: {str(e)}")
    
    return recommendations

def analyze_ebs_volumes():
    """
    Analyze EBS volumes for optimization
    """
    recommendations = []
    
    try:
        response = ec2_client.describe_volumes()
        
        for volume in response['Volumes']:
            volume_id = volume['VolumeId']
            
            # Check for unattached volumes
            if volume['State'] == 'available':
                recommendations.append({
                    'type': 'EBS_UNATTACHED',
                    'resource_id': volume_id,
                    'recommendation': 'Delete unattached EBS volume',
                    'estimated_savings': calculate_ebs_cost(volume)
                })
            
            # Check for gp2 volumes that should be gp3
            elif volume['VolumeType'] == 'gp2':
                recommendations.append({
                    'type': 'EBS_GP2_TO_GP3',
                    'resource_id': volume_id,
                    'recommendation': 'Convert gp2 to gp3 for 20% savings',
                    'estimated_savings': calculate_gp3_savings(volume)
                })
                
    except Exception as e:
        logger.error(f"Error analyzing EBS volumes: {str(e)}")
    
    return recommendations

def analyze_elastic_ips():
    """
    Analyze Elastic IPs for waste
    """
    recommendations = []
    
    try:
        response = ec2_client.describe_addresses()
        
        for eip in response['Addresses']:
            if 'InstanceId' not in eip and 'NetworkInterfaceId' not in eip:
                recommendations.append({
                    'type': 'EIP_UNATTACHED',
                    'resource_id': eip.get('AllocationId', 'unknown'),
                    'recommendation': 'Release unattached Elastic IP',
                    'estimated_savings': 3.65  # $0.005/hour * 730 hours
                })
                
    except Exception as e:
        logger.error(f"Error analyzing Elastic IPs: {str(e)}")
    
    return recommendations

def analyze_nat_gateways():
    """
    Analyze NAT Gateway usage
    """
    recommendations = []
    
    try:
        response = ec2_client.describe_nat_gateways()
        
        nat_count_by_vpc = defaultdict(int)
        for nat in response['NatGateways']:
            if nat['State'] == 'available':
                nat_count_by_vpc[nat['VpcId']] += 1
        
        for vpc_id, count in nat_count_by_vpc.items():
            if count > 1:
                # Check if this is production
                vpc_tags = ec2_client.describe_tags(
                    Filters=[
                        {'Name': 'resource-id', 'Values': [vpc_id]},
                        {'Name': 'key', 'Values': ['Environment']}
                    ]
                )
                
                is_production = any(tag['Value'] == 'production' for tag in vpc_tags.get('Tags', []))
                
                if not is_production:
                    recommendations.append({
                        'type': 'NAT_GATEWAY_REDUNDANT',
                        'resource_id': vpc_id,
                        'recommendation': f'Use single NAT Gateway for non-production (currently {count})',
                        'estimated_savings': (count - 1) * 45  # $45/month per NAT
                    })
                    
    except Exception as e:
        logger.error(f"Error analyzing NAT Gateways: {str(e)}")
    
    return recommendations

def analyze_old_snapshots():
    """
    Analyze old EBS snapshots
    """
    recommendations = []
    threshold_days = 30
    
    try:
        response = ec2_client.describe_snapshots(OwnerIds=['self'])
        cutoff_date = datetime.utcnow() - timedelta(days=threshold_days)
        
        for snapshot in response['Snapshots']:
            start_time = snapshot['StartTime'].replace(tzinfo=None)
            if start_time < cutoff_date:
                recommendations.append({
                    'type': 'SNAPSHOT_OLD',
                    'resource_id': snapshot['SnapshotId'],
                    'recommendation': f"Delete snapshot older than {threshold_days} days",
                    'estimated_savings': calculate_snapshot_cost(snapshot)
                })
                
    except Exception as e:
        logger.error(f"Error analyzing snapshots: {str(e)}")
    
    return recommendations

def analyze_reserved_instances():
    """
    Analyze Reserved Instance utilization
    """
    recommendations = []
    
    try:
        # Get RI utilization
        end_date = datetime.utcnow().date()
        start_date = end_date - timedelta(days=7)
        
        response = ce_client.get_reservation_utilization(
            TimePeriod={
                'Start': start_date.isoformat(),
                'End': end_date.isoformat()
            },
            Granularity='DAILY'
        )
        
        for result in response.get('UtilizationsByTime', []):
            utilization = float(result['Total']['UtilizationPercentage'])
            if utilization < 70:
                recommendations.append({
                    'type': 'RI_UNDERUTILIZED',
                    'resource_id': 'reserved-instances',
                    'recommendation': f'Reserved Instances underutilized ({utilization:.1f}%)',
                    'estimated_savings': 0  # Requires manual review
                })
                
    except Exception as e:
        logger.error(f"Error analyzing Reserved Instances: {str(e)}")
    
    return recommendations

def analyze_cost_trends():
    """
    Analyze cost trends and anomalies
    """
    try:
        end_date = datetime.utcnow().date()
        start_date = end_date - timedelta(days=30)
        
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.isoformat(),
                'End': end_date.isoformat()
            },
            Granularity='DAILY',
            Metrics=['UnblendedCost'],
            GroupBy=[{'Type': 'DIMENSION', 'Key': 'SERVICE'}]
        )
        
        return response
        
    except Exception as e:
        logger.error(f"Error analyzing cost trends: {str(e)}")
        return None

def get_cpu_utilization(instance_id):
    """
    Get CPU utilization statistics for an instance
    """
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=7)
        
        response = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average', 'Maximum']
        )
        
        if response['Datapoints']:
            avg = sum(d['Average'] for d in response['Datapoints']) / len(response['Datapoints'])
            max_val = max(d['Maximum'] for d in response['Datapoints'])
            return {'average': avg, 'maximum': max_val}
            
    except Exception as e:
        logger.error(f"Error getting CPU stats for {instance_id}: {str(e)}")
    
    return None

def get_rds_connections(db_id):
    """
    Get RDS connection statistics
    """
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=7)
        
        response = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/RDS',
            MetricName='DatabaseConnections',
            Dimensions=[{'Name': 'DBInstanceIdentifier', 'Value': db_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average', 'Maximum']
        )
        
        if response['Datapoints']:
            avg = sum(d['Average'] for d in response['Datapoints']) / len(response['Datapoints'])
            max_val = max(d['Maximum'] for d in response['Datapoints'])
            return {'average': avg, 'max': max_val}
            
    except Exception as e:
        logger.error(f"Error getting RDS stats for {db_id}: {str(e)}")
    
    return None

def estimate_downsize_savings(instance_type):
    """
    Estimate savings from downsizing EC2 instance
    """
    # Simplified pricing model
    hourly_costs = {
        't3.micro': 0.0104, 't3.small': 0.0208, 't3.medium': 0.0416,
        't3.large': 0.0832, 't3.xlarge': 0.1664, 't3.2xlarge': 0.3328,
        't4g.micro': 0.0084, 't4g.small': 0.0168, 't4g.medium': 0.0336,
        't4g.large': 0.0672, 't4g.xlarge': 0.1344
    }
    
    current_cost = hourly_costs.get(instance_type, 0.10) * 730  # Monthly
    suggested_cost = current_cost * 0.5  # Assume 50% reduction
    return current_cost - suggested_cost

def estimate_rds_downsize_savings(db_class):
    """
    Estimate savings from downsizing RDS instance
    """
    hourly_costs = {
        'db.t3.micro': 0.017, 'db.t3.small': 0.034, 'db.t3.medium': 0.068,
        'db.t3.large': 0.136, 'db.t3.xlarge': 0.272,
        'db.t4g.micro': 0.016, 'db.t4g.small': 0.032, 'db.t4g.medium': 0.065,
        'db.t4g.large': 0.129, 'db.t4g.xlarge': 0.258
    }
    
    current_cost = hourly_costs.get(db_class, 0.20) * 730
    suggested_cost = current_cost * 0.5
    return current_cost - suggested_cost

def calculate_total_savings(recommendations):
    """
    Calculate total potential savings
    """
    return sum(r.get('estimated_savings', 0) for r in recommendations)

def generate_report(recommendations, cost_analysis):
    """
    Generate optimization report
    """
    report = f"""
Cost Optimization Report - {datetime.utcnow().strftime('%Y-%m-%d')}
{'=' * 60}

Environment: {os.environ.get('ENVIRONMENT', 'unknown')}
Total Recommendations: {len(recommendations)}
Potential Monthly Savings: ${calculate_total_savings(recommendations):,.2f}

Top Recommendations:
{'-' * 40}
"""
    
    # Group by type
    by_type = defaultdict(list)
    for rec in recommendations:
        by_type[rec['type']].append(rec)
    
    for rec_type, items in by_type.items():
        total = sum(r.get('estimated_savings', 0) for r in items)
        report += f"\n{rec_type}: {len(items)} items (${total:,.2f}/month)\n"
        for item in items[:3]:  # Top 3
            report += f"  - {item['resource_id']}: {item['recommendation']}\n"
    
    return report

def send_notification(report):
    """
    Send notification with recommendations
    """
    try:
        sns_topic = os.environ.get('SNS_TOPIC_ARN')
        if sns_topic:
            sns_client.publish(
                TopicArn=sns_topic,
                Subject=f"Cost Optimization Report - {os.environ.get('ENVIRONMENT')}",
                Message=report
            )
            logger.info("Cost optimization report sent")
    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")

def estimate_reservation_savings(instance_type):
    """
    Estimate savings from Reserved Instances
    """
    # Assume 30% savings with 1-year commitment
    hourly_costs = {'t3.large': 0.0832, 't3.xlarge': 0.1664}
    monthly_cost = hourly_costs.get(instance_type, 0.10) * 730
    return monthly_cost * 0.30

def estimate_multi_az_savings(db_class):
    """
    Estimate savings from disabling Multi-AZ
    """
    # Multi-AZ roughly doubles the cost
    hourly_costs = {'db.t3.large': 0.136, 'db.t3.xlarge': 0.272}
    monthly_cost = hourly_costs.get(db_class, 0.20) * 730
    return monthly_cost * 0.5

def calculate_ebs_cost(volume):
    """
    Calculate EBS volume monthly cost
    """
    size_gb = volume['Size']
    volume_type = volume['VolumeType']
    costs_per_gb = {'gp2': 0.10, 'gp3': 0.08, 'io1': 0.125, 'io2': 0.125}
    return size_gb * costs_per_gb.get(volume_type, 0.10)

def calculate_gp3_savings(volume):
    """
    Calculate savings from gp2 to gp3 conversion
    """
    size_gb = volume['Size']
    return size_gb * 0.02  # $0.02/GB/month savings

def calculate_snapshot_cost(snapshot):
    """
    Calculate snapshot storage cost
    """
    size_gb = snapshot.get('VolumeSize', 0)
    return size_gb * 0.05  # $0.05/GB/month for snapshots
"""
AWS Cost Controller Lambda Function
Automatically takes actions when spending limits are reached
"""

import json
import os
import boto3
from datetime import datetime, timedelta
from decimal import Decimal

# Initialize AWS clients
ecs = boto3.client('ecs')
autoscaling = boto3.client('autoscaling')
rds = boto3.client('rds')
ce = boto3.client('ce')
sns = boto3.client('sns')
budgets = boto3.client('budgets')

# Environment variables
ENVIRONMENT = os.environ['ENVIRONMENT']
MAX_BUDGET = Decimal(os.environ['MAX_BUDGET'])
ACTIONS = json.loads(os.environ['ACTIONS'])
CLUSTER_NAME = f"diagnyx-{ENVIRONMENT}"

def handler(event, context):
    """Main Lambda handler"""
    print(f"Event received: {json.dumps(event)}")
    
    # Get current spending
    current_spend = get_current_spend()
    budget_percentage = (current_spend / MAX_BUDGET) * 100
    
    print(f"Current spend: ${current_spend:.2f} ({budget_percentage:.1f}% of ${MAX_BUDGET})")
    
    # Determine actions based on budget percentage
    actions_to_take = determine_actions(budget_percentage)
    
    if actions_to_take:
        print(f"Taking actions: {actions_to_take}")
        execute_actions(actions_to_take, current_spend, budget_percentage)
    else:
        print("No actions needed at current spending level")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'current_spend': float(current_spend),
            'budget_percentage': float(budget_percentage),
            'actions_taken': actions_to_take
        })
    }

def get_current_spend():
    """Get current month's AWS spending"""
    now = datetime.now()
    start_date = now.replace(day=1).strftime('%Y-%m-%d')
    end_date = (now + timedelta(days=1)).strftime('%Y-%m-%d')
    
    try:
        response = ce.get_cost_and_usage(
            TimePeriod={
                'Start': start_date,
                'End': end_date
            },
            Granularity='MONTHLY',
            Metrics=['UnblendedCost']
        )
        
        cost = Decimal(response['ResultsByTime'][0]['Total']['UnblendedCost']['Amount'])
        return cost
    except Exception as e:
        print(f"Error getting cost data: {e}")
        return Decimal('0')

def determine_actions(budget_percentage):
    """Determine which actions to take based on budget percentage"""
    actions = []
    
    for threshold, threshold_actions in ACTIONS.items():
        if budget_percentage >= float(threshold):
            actions.extend(threshold_actions)
    
    # Remove duplicates while preserving order
    seen = set()
    unique_actions = []
    for action in actions:
        if action not in seen:
            seen.add(action)
            unique_actions.append(action)
    
    return unique_actions

def execute_actions(actions, current_spend, budget_percentage):
    """Execute the determined actions"""
    
    for action in actions:
        try:
            if action == "alert":
                send_alert(current_spend, budget_percentage)
            
            elif action == "scale_down":
                scale_down_services()
            
            elif action == "stop_non_essential":
                stop_non_essential_services()
            
            elif action == "scale_down_non_critical":
                scale_down_non_critical_services()
            
            elif action == "emergency_scale_down":
                emergency_scale_down()
            
            elif action == "stop_batch_jobs":
                stop_batch_jobs()
            
            elif action == "critical_only_mode":
                enable_critical_only_mode()
            
            elif action == "page_oncall":
                page_oncall_team(current_spend, budget_percentage)
            
            elif action == "review_required":
                request_manual_review(current_spend, budget_percentage)
            
            print(f"Successfully executed action: {action}")
            
        except Exception as e:
            print(f"Error executing action {action}: {e}")
            send_error_alert(action, str(e))

def send_alert(current_spend, budget_percentage):
    """Send spending alert via SNS"""
    message = f"""
    ⚠️ AWS Spending Alert for {ENVIRONMENT}
    
    Current Spend: ${current_spend:.2f}
    Budget: ${MAX_BUDGET:.2f}
    Percentage: {budget_percentage:.1f}%
    
    Please review AWS Cost Explorer for details.
    """
    
    sns.publish(
        TopicArn=os.environ.get('SNS_TOPIC_ARN', ''),
        Subject=f'[{ENVIRONMENT}] AWS Spending at {budget_percentage:.0f}%',
        Message=message
    )

def scale_down_services():
    """Scale down ECS services to minimum capacity"""
    try:
        # List all services in the cluster
        services = ecs.list_services(cluster=CLUSTER_NAME)['serviceArns']
        
        for service_arn in services:
            service_name = service_arn.split('/')[-1]
            
            # Skip critical services
            if service_name in ['api-gateway', 'user-service']:
                continue
            
            # Scale down to 1 instance
            ecs.update_service(
                cluster=CLUSTER_NAME,
                service=service_name,
                desiredCount=1
            )
            print(f"Scaled down {service_name} to 1 instance")
            
    except Exception as e:
        print(f"Error scaling down services: {e}")

def stop_non_essential_services():
    """Stop non-essential ECS services"""
    non_essential = [
        'diagnyx-ui'
    ]
    
    try:
        for service_name in non_essential:
            try:
                ecs.update_service(
                    cluster=CLUSTER_NAME,
                    service=service_name,
                    desiredCount=0
                )
                print(f"Stopped non-essential service: {service_name}")
            except:
                pass  # Service might not exist in this environment
                
    except Exception as e:
        print(f"Error stopping non-essential services: {e}")

def scale_down_non_critical_services():
    """Scale down non-critical services in production"""
    if ENVIRONMENT != 'production':
        return scale_down_services()
    
    # Production-specific scaling
    scaling_map = {
        'diagnyx-ui': 1
    }
    
    try:
        for service_name, min_count in scaling_map.items():
            try:
                ecs.update_service(
                    cluster=CLUSTER_NAME,
                    service=service_name,
                    desiredCount=min_count
                )
                print(f"Scaled {service_name} to {min_count} instances")
            except:
                pass
                
    except Exception as e:
        print(f"Error in production scaling: {e}")

def emergency_scale_down():
    """Emergency scale down - keep only critical services"""
    critical_services = ['api-gateway', 'user-service']
    
    try:
        services = ecs.list_services(cluster=CLUSTER_NAME)['serviceArns']
        
        for service_arn in services:
            service_name = service_arn.split('/')[-1]
            
            if service_name in critical_services:
                # Scale critical services to minimum
                ecs.update_service(
                    cluster=CLUSTER_NAME,
                    service=service_name,
                    desiredCount=1
                )
            else:
                # Stop non-critical services
                ecs.update_service(
                    cluster=CLUSTER_NAME,
                    service=service_name,
                    desiredCount=0
                )
            
        print("Emergency scale down completed")
        
    except Exception as e:
        print(f"Error in emergency scale down: {e}")

def stop_batch_jobs():
    """Stop any running batch jobs or scheduled tasks"""
    try:
        # Stop ECS tasks that are not part of services
        tasks = ecs.list_tasks(cluster=CLUSTER_NAME, desiredStatus='RUNNING')['taskArns']
        
        for task_arn in tasks:
            # Check if task is part of a service
            task = ecs.describe_tasks(cluster=CLUSTER_NAME, tasks=[task_arn])['tasks'][0]
            
            if 'group' not in task or not task['group'].startswith('service:'):
                # This is a standalone task, stop it
                ecs.stop_task(cluster=CLUSTER_NAME, task=task_arn, reason='Budget exceeded')
                print(f"Stopped batch task: {task_arn}")
                
    except Exception as e:
        print(f"Error stopping batch jobs: {e}")

def enable_critical_only_mode():
    """Enable critical-only mode - maximum cost savings"""
    
    # Stop all non-critical services
    stop_non_essential_services()
    
    # Scale down Auto Scaling Groups
    try:
        asgs = autoscaling.describe_auto_scaling_groups(
            Filters=[
                {'Name': 'tag:Environment', 'Values': [ENVIRONMENT]}
            ]
        )['AutoScalingGroups']
        
        for asg in asgs:
            autoscaling.update_auto_scaling_group(
                AutoScalingGroupName=asg['AutoScalingGroupName'],
                MinSize=0,
                DesiredCapacity=0
            )
            print(f"Scaled ASG {asg['AutoScalingGroupName']} to 0")
            
    except Exception as e:
        print(f"Error scaling ASGs: {e}")
    
    # Stop RDS instances (except production)
    if ENVIRONMENT != 'production':
        try:
            db_instances = rds.describe_db_instances()['DBInstances']
            
            for db in db_instances:
                if f'diagnyx-{ENVIRONMENT}' in db['DBInstanceIdentifier']:
                    rds.stop_db_instance(DBInstanceIdentifier=db['DBInstanceIdentifier'])
                    print(f"Stopped RDS instance: {db['DBInstanceIdentifier']}")
                    
        except Exception as e:
            print(f"Error stopping RDS: {e}")

def page_oncall_team(current_spend, budget_percentage):
    """Page the on-call team for immediate attention"""
    message = f"""
    🚨 CRITICAL: AWS Budget Exceeded for {ENVIRONMENT}
    
    Current Spend: ${current_spend:.2f}
    Budget: ${MAX_BUDGET:.2f}
    Percentage: {budget_percentage:.1f}%
    
    IMMEDIATE ACTION REQUIRED!
    
    Automatic cost controls have been activated.
    Please review and take manual action if needed.
    
    Cost Explorer: https://console.aws.amazon.com/cost-management/
    """
    
    # Send high-priority alert
    sns.publish(
        TopicArn=os.environ.get('SNS_TOPIC_ARN', ''),
        Subject=f'🚨 CRITICAL: {ENVIRONMENT} Budget at {budget_percentage:.0f}%',
        Message=message,
        MessageAttributes={
            'priority': {'DataType': 'String', 'StringValue': 'HIGH'},
            'alert_type': {'DataType': 'String', 'StringValue': 'BUDGET_CRITICAL'}
        }
    )

def request_manual_review(current_spend, budget_percentage):
    """Request manual review of spending"""
    message = f"""
    Manual Review Required for {ENVIRONMENT}
    
    Current Spend: ${current_spend:.2f}
    Budget: ${MAX_BUDGET:.2f}
    Percentage: {budget_percentage:.1f}%
    
    Please review:
    1. Unusual spending patterns
    2. Unused resources
    3. Optimization opportunities
    
    Cost Explorer: https://console.aws.amazon.com/cost-management/
    """
    
    sns.publish(
        TopicArn=os.environ.get('SNS_TOPIC_ARN', ''),
        Subject=f'[{ENVIRONMENT}] Manual Cost Review Required',
        Message=message
    )

def send_error_alert(action, error):
    """Send alert when an action fails"""
    message = f"""
    Error executing cost control action in {ENVIRONMENT}
    
    Action: {action}
    Error: {error}
    
    Please check CloudWatch logs for details.
    """
    
    try:
        sns.publish(
            TopicArn=os.environ.get('SNS_TOPIC_ARN', ''),
            Subject=f'[{ENVIRONMENT}] Cost Control Action Failed',
            Message=message
        )
    except:
        pass  # Don't fail if we can't send the error alert
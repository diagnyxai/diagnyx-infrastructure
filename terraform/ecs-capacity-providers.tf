# ECS Capacity Providers for cost-optimized EC2 instances
# Uses mix of Spot (70%) and On-Demand (30%) for cost savings with reliability

# Launch Template for ECS instances
resource "aws_launch_template" "ecs" {
  name_prefix   = "${local.ecs_name}-"
  image_id      = data.aws_ami.ecs_optimized.id
  # Environment-specific instance types
  instance_type = var.environment == "production" ? "t4g.small" : (
    var.environment == "uat" ? "t4g.micro" : "t4g.nano"
  )

  # Use ARM-based Graviton instances for 20% cost savings
  instance_requirements {
    vcpu_count {
      min = 2
      max = 4
    }
    memory_mib {
      min = 2048
      max = 8192
    }
    instance_generations = ["current"]
    accelerator_count {
      max = 0
    }
    # Prefer ARM for cost savings
    cpu_manufacturers = ["amazon-web-services", "amd", "intel"]
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance.arn
  }

  user_data = base64encode(templatefile("${path.module}/templates/ecs-user-data.sh", {
    cluster_name = aws_ecs_cluster.main.name
    region       = var.aws_region
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20  # Minimum 20GB for all environments
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = var.environment == "production"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${local.ecs_name}-instance"
        Type = "ecs-container-instance"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name = "${local.ecs_name}-volume"
      }
    )
  }
}

# Auto Scaling Group for On-Demand instances
resource "aws_autoscaling_group" "ecs_on_demand" {
  name                = "${local.ecs_name}-on-demand"
  vpc_zone_identifier = aws_subnet.private[*].id
  # Environment-specific capacity settings
  min_size = (var.environment == "production" || var.environment == "uat") ? 1 : 0
  max_size = var.environment == "production" ? 3 : (var.environment == "uat" ? 2 : 1)
  desired_capacity = (var.environment == "production" || var.environment == "uat") ? 1 : 0

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.ecs_name}-on-demand"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for Spot instances
resource "aws_autoscaling_group" "ecs_spot" {
  name                = "${local.ecs_name}-spot"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = 0  # Spot can scale to 0
  max_size = var.environment == "production" ? 2 : (var.environment == "uat" ? 1 : 1)
  desired_capacity    = 0  # Start with 0 spot instances to minimize cost

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs.id
        version            = "$Latest"
      }

      override {
        instance_type = "t4g.small"
        weighted_capacity = 1
      }
      override {
        instance_type = "t4g.medium"
        weighted_capacity = 2
      }
      override {
        instance_type = "t3a.small"
        weighted_capacity = 1
      }
      override {
        instance_type = "t3a.medium"
        weighted_capacity = 2
      }
    }

    instances_distribution {
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
      spot_instance_pools                      = 4
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.ecs_name}-spot"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Capacity Provider for On-Demand
resource "aws_ecs_capacity_provider" "on_demand" {
  name = "${local.ecs_name}-on-demand"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_on_demand.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 10
      instance_warmup_period    = 60
    }
  }

  tags = local.common_tags
}

# ECS Capacity Provider for Spot
resource "aws_ecs_capacity_provider" "spot" {
  name = "${local.ecs_name}-spot"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_spot.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 10
      instance_warmup_period    = 60
    }
  }

  tags = local.common_tags
}

# IAM Instance Profile for ECS instances
resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${local.ecs_name}-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

resource "aws_iam_role" "ecs_instance" {
  name = "${local.ecs_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Security Group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name        = "${local.ecs_name}-instances"
  description = "Security group for ECS container instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "All traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-instances"
    }
  )
}

# Data source for latest ECS-optimized AMI
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-arm64-ebs"]  # ARM64 for cost savings
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Variables for customization
variable "ecs_instance_type" {
  description = "Instance type for ECS container instances"
  type        = string
  default     = "t4g.nano"  # Absolute minimum for all environments
}

# Enhanced scheduled scaling for non-production environments
# On-Demand instances - Weekday scaling
resource "aws_autoscaling_schedule" "scale_down_weekday" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${local.ecs_name}-scale-down-weekday"
  autoscaling_group_name = aws_autoscaling_group.ecs_on_demand.name
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 19 * * MON-FRI"  # 7 PM UTC weekdays
}

resource "aws_autoscaling_schedule" "scale_up_weekday" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${local.ecs_name}-scale-up-weekday"
  autoscaling_group_name = aws_autoscaling_group.ecs_on_demand.name
  min_size               = 0
  max_size               = 2
  desired_capacity       = 1
  recurrence             = "0 11 * * MON-FRI"  # 11 AM UTC weekdays
}

# On-Demand instances - Weekend scaling (complete shutdown)
resource "aws_autoscaling_schedule" "scale_down_weekend" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${local.ecs_name}-scale-down-weekend"
  autoscaling_group_name = aws_autoscaling_group.ecs_on_demand.name
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 18 * * FRI"  # 6 PM Friday
}

resource "aws_autoscaling_schedule" "scale_up_monday" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${local.ecs_name}-scale-up-monday"
  autoscaling_group_name = aws_autoscaling_group.ecs_on_demand.name
  min_size               = 0
  max_size               = 2
  desired_capacity       = 1
  recurrence             = "0 11 * * MON"  # 11 AM Monday
}

# Spot instances - Similar scheduling for additional cost savings
resource "aws_autoscaling_schedule" "spot_scale_down_weekday" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${local.ecs_name}-spot-scale-down-weekday"
  autoscaling_group_name = aws_autoscaling_group.ecs_spot.name
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 19 * * MON-FRI"  # 7 PM UTC weekdays
}

resource "aws_autoscaling_schedule" "spot_scale_down_weekend" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${local.ecs_name}-spot-scale-down-weekend"
  autoscaling_group_name = aws_autoscaling_group.ecs_spot.name
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 18 * * FRI"  # 6 PM Friday
}
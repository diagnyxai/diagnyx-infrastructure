# Auto-scaling configuration for ECS services

# User Service Auto-scaling
resource "aws_appautoscaling_target" "user_service" {
  max_capacity       = local.service_scaling.user_service.max_capacity
  min_capacity       = local.service_scaling.user_service.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.user_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "user_service_cpu" {
  name               = "${aws_ecs_service.user_service.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.user_service.resource_id
  scalable_dimension = aws_appautoscaling_target.user_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.user_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = local.service_scaling.user_service.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "user_service_memory" {
  name               = "${aws_ecs_service.user_service.name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.user_service.resource_id
  scalable_dimension = aws_appautoscaling_target.user_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.user_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = local.service_scaling.user_service.target_memory
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Observability Service Auto-scaling
resource "aws_appautoscaling_target" "observability_service" {
  max_capacity       = local.service_scaling.observability_service.max_capacity
  min_capacity       = local.service_scaling.observability_service.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.observability_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "observability_service_cpu" {
  name               = "${aws_ecs_service.observability_service.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.observability_service.resource_id
  scalable_dimension = aws_appautoscaling_target.observability_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.observability_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = local.service_scaling.observability_service.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# AI Quality Service Auto-scaling
resource "aws_appautoscaling_target" "ai_quality_service" {
  max_capacity       = local.service_scaling.ai_quality_service.max_capacity
  min_capacity       = local.service_scaling.ai_quality_service.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.ai_quality_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ai_quality_service_cpu" {
  name               = "${aws_ecs_service.ai_quality_service.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ai_quality_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ai_quality_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ai_quality_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = local.service_scaling.ai_quality_service.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Optimization Service Auto-scaling
resource "aws_appautoscaling_target" "optimization_service" {
  max_capacity       = local.service_scaling.optimization_service.max_capacity
  min_capacity       = local.service_scaling.optimization_service.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.optimization_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "optimization_service_cpu" {
  name               = "${aws_ecs_service.optimization_service.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.optimization_service.resource_id
  scalable_dimension = aws_appautoscaling_target.optimization_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.optimization_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = local.service_scaling.optimization_service.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# API Gateway Auto-scaling
resource "aws_appautoscaling_target" "api_gateway" {
  max_capacity       = local.service_scaling.api_gateway.max_capacity
  min_capacity       = local.service_scaling.api_gateway.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_gateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_gateway_cpu" {
  name               = "${aws_ecs_service.api_gateway.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api_gateway.resource_id
  scalable_dimension = aws_appautoscaling_target.api_gateway.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api_gateway.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = local.service_scaling.api_gateway.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Dashboard Service Auto-scaling
resource "aws_appautoscaling_target" "dashboard_service" {
  max_capacity       = local.service_scaling.dashboard_service.max_capacity
  min_capacity       = local.service_scaling.dashboard_service.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.dashboard_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "dashboard_service_cpu" {
  name               = "${aws_ecs_service.dashboard_service.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dashboard_service.resource_id
  scalable_dimension = aws_appautoscaling_target.dashboard_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dashboard_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = local.service_scaling.dashboard_service.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Marketing UI Auto-scaling
resource "aws_appautoscaling_target" "diagnyx_ui" {
  max_capacity       = local.service_scaling.diagnyx_ui.max_capacity
  min_capacity       = local.service_scaling.diagnyx_ui.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.diagnyx_ui.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "diagnyx_ui_cpu" {
  name               = "${aws_ecs_service.diagnyx_ui.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.diagnyx_ui.resource_id
  scalable_dimension = aws_appautoscaling_target.diagnyx_ui.scalable_dimension
  service_namespace  = aws_appautoscaling_target.diagnyx_ui.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = local.service_scaling.diagnyx_ui.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Scheduled Scaling for Non-Production Environments
# Scale down services during off-hours to save costs

resource "aws_appautoscaling_scheduled_action" "scale_down_evening" {
  for_each = var.environment != "production" ? {
    user_service          = aws_appautoscaling_target.user_service.resource_id
    observability_service = aws_appautoscaling_target.observability_service.resource_id
    ai_quality_service    = aws_appautoscaling_target.ai_quality_service.resource_id
    optimization_service  = aws_appautoscaling_target.optimization_service.resource_id
    api_gateway          = aws_appautoscaling_target.api_gateway.resource_id
    dashboard_service    = aws_appautoscaling_target.dashboard_service.resource_id
    diagnyx_ui           = aws_appautoscaling_target.diagnyx_ui.resource_id
  } : {}

  name               = "${split("/", each.value)[2]}-scale-down-evening"
  service_namespace  = "ecs"
  resource_id        = each.value
  scalable_dimension = "ecs:service:DesiredCount"
  schedule           = "cron(0 19 ? * MON-FRI *)"  # 7 PM UTC on weekdays

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}

resource "aws_appautoscaling_scheduled_action" "scale_up_morning" {
  for_each = var.environment != "production" ? {
    user_service          = aws_appautoscaling_target.user_service.resource_id
    observability_service = aws_appautoscaling_target.observability_service.resource_id
    ai_quality_service    = aws_appautoscaling_target.ai_quality_service.resource_id
    optimization_service  = aws_appautoscaling_target.optimization_service.resource_id
    api_gateway          = aws_appautoscaling_target.api_gateway.resource_id
    dashboard_service    = aws_appautoscaling_target.dashboard_service.resource_id
    diagnyx_ui           = aws_appautoscaling_target.diagnyx_ui.resource_id
  } : {}

  name               = "${split("/", each.value)[2]}-scale-up-morning"
  service_namespace  = "ecs"
  resource_id        = each.value
  scalable_dimension = "ecs:service:DesiredCount"
  schedule           = "cron(0 11 ? * MON-FRI *)"  # 11 AM UTC on weekdays

  scalable_target_action {
    min_capacity = 1
    max_capacity = 3
  }
}
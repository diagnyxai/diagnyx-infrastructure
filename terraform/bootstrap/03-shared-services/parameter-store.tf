# Systems Manager Parameter Store - Shared Configuration
# Cost: FREE (Standard parameters)
# Purpose: Centralized configuration management across environments

locals {
  # Shared configuration parameters
  shared_parameters = {
    # Model routing configuration
    "/diagnyx/shared/models/routing-config" = {
      value = jsonencode({
        cascade_threshold = 0.7
        cost_limit        = 1.0
        cache_ttl         = 3600
        models = {
          tier1 = "claude-3-haiku"
          tier2 = "claude-3-sonnet"
          tier3 = "claude-3-opus"
        }
      })
      description = "RouteLLM configuration for model routing"
    }
    
    # Supported LLM models
    "/diagnyx/shared/models/supported-llms" = {
      value = jsonencode({
        openai = ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"]
        anthropic = ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
        google = ["gemini-pro", "gemini-pro-vision"]
        meta = ["llama-2-70b", "llama-2-13b"]
      })
      description = "List of supported LLM models"
    }
    
    # Evaluation metrics configuration
    "/diagnyx/shared/evaluation/metrics" = {
      value = jsonencode({
        accuracy = {
          enabled   = true
          threshold = 0.85
        }
        relevance = {
          enabled   = true
          threshold = 0.80
        }
        coherence = {
          enabled   = true
          threshold = 0.75
        }
        safety = {
          enabled   = true
          threshold = 0.95
        }
      })
      description = "Evaluation metrics configuration"
    }
    
    # Hallucination detection thresholds
    "/diagnyx/shared/hallucination/thresholds" = {
      value = jsonencode({
        semantic_entropy = {
          low    = 0.3
          medium = 0.6
          high   = 0.8
        }
        check_framework = {
          confidence_threshold = 0.7
          min_evidence_count   = 2
        }
        ensemble = {
          voting_threshold = 0.6
          min_voters       = 3
        }
      })
      description = "Hallucination detection thresholds"
    }
    
    # Service endpoints (populated during deployment)
    "/diagnyx/shared/endpoints/services" = {
      value = jsonencode({
        user_service          = ""
        observability_service = ""
        ai_quality_service    = ""
        optimization_service  = ""
        api_gateway          = ""
      })
      description = "Service endpoint URLs"
    }
    
    # Feature flags
    "/diagnyx/shared/features/flags" = {
      value = jsonencode({
        hallucination_detection = true
        cost_optimization      = true
        prompt_versioning      = true
        ab_testing            = false
        auto_scaling          = true
      })
      description = "Feature flags for enabling/disabling features"
    }
    
    # Rate limiting configuration
    "/diagnyx/shared/ratelimit/config" = {
      value = jsonencode({
        default = {
          requests_per_second = 100
          burst_size          = 200
        }
        by_tier = {
          free = {
            requests_per_second = 10
            burst_size          = 20
          }
          standard = {
            requests_per_second = 100
            burst_size          = 200
          }
          premium = {
            requests_per_second = 1000
            burst_size          = 2000
          }
        }
      })
      description = "Rate limiting configuration"
    }
    
    # Observability configuration
    "/diagnyx/shared/observability/config" = {
      value = jsonencode({
        sampling_rate = 0.1
        trace_enabled = true
        metrics_enabled = true
        logs_enabled = true
        retention_days = 30
      })
      description = "Observability configuration"
    }
    
    # Cache configuration
    "/diagnyx/shared/cache/config" = {
      value = jsonencode({
        redis = {
          default_ttl = 3600
          max_memory  = "2gb"
          eviction_policy = "allkeys-lru"
        }
        cloudfront = {
          default_ttl = 86400
          max_ttl     = 604800
        }
      })
      description = "Cache configuration"
    }
    
    # Notification channels
    "/diagnyx/shared/notifications/channels" = {
      value = jsonencode({
        slack = {
          webhook_url = ""
          channels = {
            alerts     = "#alerts"
            deployments = "#deployments"
            costs      = "#costs"
          }
        }
        email = {
          ops_list      = "ops@diagnyx.ai"
          security_list = "security@diagnyx.ai"
          finance_list  = "finance@diagnyx.ai"
        }
      })
      description = "Notification channel configuration"
    }
  }
  
  # Environment-specific parameter prefixes
  environment_parameters = {
    "/diagnyx/${var.environment}/config/database" = {
      value       = "{}"
      description = "Database configuration for ${var.environment}"
    }
    "/diagnyx/${var.environment}/config/services" = {
      value       = "{}"
      description = "Service configuration for ${var.environment}"
    }
    "/diagnyx/${var.environment}/config/features" = {
      value       = "{}"
      description = "Feature configuration for ${var.environment}"
    }
  }
}

# Create shared parameters (only in shared account)
resource "aws_ssm_parameter" "shared" {
  for_each = var.is_shared_account ? local.shared_parameters : {}
  
  name        = each.key
  type        = "String"
  value       = each.value.value
  description = each.value.description
  tier        = "Standard"  # Free tier
  
  tags = merge(
    local.common_tags,
    {
      Type = "shared-config"
    }
  )
  
  lifecycle {
    ignore_changes = [value]  # Allow manual updates
  }
}

# Create environment-specific parameters
resource "aws_ssm_parameter" "environment" {
  for_each = local.environment_parameters
  
  name        = each.key
  type        = "String"
  value       = each.value.value
  description = each.value.description
  tier        = "Standard"
  
  tags = merge(
    local.common_tags,
    {
      Type = "environment-config"
    }
  )
  
  lifecycle {
    ignore_changes = [value]
  }
}

# Parameter Store access policy for cross-account
resource "aws_iam_policy" "parameter_store_read" {
  count = var.is_shared_account ? 1 : 0
  
  name        = "diagnyx-parameter-store-read"
  description = "Allow reading shared parameters"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/diagnyx/shared/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Outputs
output "shared_parameter_names" {
  value = var.is_shared_account ? {
    for k, v in aws_ssm_parameter.shared : k => v.name
  } : {}
  description = "Names of shared parameters"
}

output "environment_parameter_names" {
  value = {
    for k, v in aws_ssm_parameter.environment : k => v.name
  }
  description = "Names of environment-specific parameters"
}
environment = "shared"
assume_role_arn = ""
external_id = "diagnyx-secure-2024"
budget_alert_email = "admin@diagnyx.com"
alarm_email = "admin@diagnyx.com"
monthly_budget_limit = "50"

ecr_repositories = [
  "user-service",
  "observability-service",
  "ai-quality-service",
  "optimization-service",
  "api-gateway",
  "dashboard-service",
  "diagnyx-ui"
]

initial_parameters = {
  "database_host" = "placeholder"
  "redis_host" = "placeholder"
  "environment" = "master"
}

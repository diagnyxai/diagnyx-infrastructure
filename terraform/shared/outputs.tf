# Shared Resources Outputs

# ECR Repository URLs
output "ecr_repositories" {
  description = "Map of all ECR repository URLs"
  value       = module.shared_resources.ecr_repositories
}

output "user_service_ecr_repository_url" {
  description = "URL of the user service ECR repository"
  value       = module.shared_resources.user_service_ecr_repository_url
}

output "api_gateway_ecr_repository_url" {
  description = "URL of the API gateway ECR repository"
  value       = module.shared_resources.api_gateway_ecr_repository_url
}

output "diagnyx_ui_ecr_repository_url" {
  description = "URL of the UI ECR repository"
  value       = module.shared_resources.diagnyx_ui_ecr_repository_url
}

# Route 53 Outputs
output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = module.shared_resources.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Route 53 hosted zone name servers"
  value       = module.shared_resources.hosted_zone_name_servers
}
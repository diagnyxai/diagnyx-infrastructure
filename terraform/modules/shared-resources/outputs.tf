# ECR Repository Outputs
output "user_service_ecr_repository_url" {
  description = "URL of the user service ECR repository"
  value       = aws_ecr_repository.user_service.repository_url
}

output "api_gateway_ecr_repository_url" {
  description = "URL of the API gateway ECR repository"
  value       = aws_ecr_repository.api_gateway.repository_url
}

output "diagnyx_ui_ecr_repository_url" {
  description = "URL of the UI ECR repository"
  value       = aws_ecr_repository.diagnyx_ui.repository_url
}

output "ecr_repositories" {
  description = "Map of all ECR repository URLs"
  value = {
    user_service = aws_ecr_repository.user_service.repository_url
    api_gateway  = aws_ecr_repository.api_gateway.repository_url
    diagnyx_ui   = aws_ecr_repository.diagnyx_ui.repository_url
  }
}

# Route 53 Outputs
output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : null
}

output "hosted_zone_name_servers" {
  description = "Route 53 hosted zone name servers"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}
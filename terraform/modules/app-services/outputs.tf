output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "security_group_id" {
  description = "ID of the ECS services security group"
  value       = aws_security_group.ecs_services.id
}

# Placeholder for CloudFront distribution (production only)
output "cloudfront_distribution_domain" {
  description = "CloudFront distribution domain"
  value       = var.environment == "production" ? "cdn.diagnyx.ai" : null
}
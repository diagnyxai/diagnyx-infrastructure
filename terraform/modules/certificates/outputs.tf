# Certificate Management Module Outputs

output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].arn : ""
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].domain_name : ""
}

output "certificate_status" {
  description = "Status of the certificate validation"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].status : ""
}

output "certificate_validation_arn" {
  description = "ARN of the certificate validation"
  value       = var.domain_name != "" ? aws_acm_certificate_validation.main[0].certificate_arn : ""
}

output "subject_alternative_names" {
  description = "List of subject alternative names"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].subject_alternative_names : []
}

output "certificate_not_after" {
  description = "Certificate expiry date"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].not_after : ""
}

output "certificate_not_before" {
  description = "Certificate start date"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].not_before : ""
}

output "validation_records" {
  description = "DNS validation records"
  value = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
    }
  } : {}
}

output "monitoring_enabled" {
  description = "Whether certificate monitoring is enabled"
  value       = var.enable_monitoring
}

output "monitor_function_arn" {
  description = "ARN of the certificate monitoring Lambda function"
  value       = var.enable_monitoring ? aws_lambda_function.cert_monitor[0].arn : ""
}

output "monitor_schedule_arn" {
  description = "ARN of the certificate monitoring schedule"
  value       = var.enable_monitoring ? aws_cloudwatch_event_rule.cert_monitor_schedule[0].arn : ""
}

# Helper outputs for integration with ALB/CloudFront
output "certificate_for_alb" {
  description = "Certificate ARN formatted for ALB usage"
  value       = var.domain_name != "" ? aws_acm_certificate_validation.main[0].certificate_arn : ""
}

output "certificate_for_cloudfront" {
  description = "Certificate details for CloudFront usage (must be in us-east-1)"
  value = var.domain_name != "" ? {
    arn         = aws_acm_certificate_validation.main[0].certificate_arn
    domain_name = aws_acm_certificate.main[0].domain_name
    # Note: CloudFront requires certificates to be in us-east-1 region
    region_requirement = "us-east-1"
  } : {}
}
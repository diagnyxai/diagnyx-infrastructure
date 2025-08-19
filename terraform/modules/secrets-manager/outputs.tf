output "secret_arns" {
  description = "ARNs of all created secrets"
  value = {
    for k, v in aws_secretsmanager_secret.secrets : k => v.arn
  }
  sensitive = true
}

output "secret_ids" {
  description = "IDs of all created secrets"
  value = {
    for k, v in aws_secretsmanager_secret.secrets : k => v.id
  }
}

output "secret_names" {
  description = "Names of all created secrets"
  value = {
    for k, v in aws_secretsmanager_secret.secrets : k => v.name
  }
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role with secrets access"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_secrets_policy_arn" {
  description = "ARN of the ECS secrets policy"
  value       = aws_iam_policy.ecs_secrets_policy.arn
}

output "lambda_secrets_policy_arn" {
  description = "ARN of the Lambda secrets policy"
  value       = aws_iam_policy.lambda_secrets_policy.arn
}

output "service_specific_policy_arns" {
  description = "ARNs of service-specific secrets policies"
  value = {
    for k, v in aws_iam_policy.service_specific_policy : k => v.arn
  }
}

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function (if enabled)"
  value       = var.enable_rotation ? aws_lambda_function.rotation[0].arn : null
}
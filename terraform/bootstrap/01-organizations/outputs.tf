# Outputs for AWS Organizations

output "organization_id" {
  value       = aws_organizations_organization.main.id
  description = "The ID of the organization"
}

output "organization_arn" {
  value       = aws_organizations_organization.main.arn
  description = "The ARN of the organization"
}

output "master_account_id" {
  value       = aws_organizations_organization.main.master_account_id
  description = "The ID of the master account"
}

output "dev_account_id" {
  value       = aws_organizations_account.dev.id
  description = "Development account ID"
}

output "staging_account_id" {
  value       = aws_organizations_account.staging.id
  description = "Staging account ID"
}

output "uat_account_id" {
  value       = aws_organizations_account.uat.id
  description = "UAT account ID"
}

output "prod_account_id" {
  value       = aws_organizations_account.production.id
  description = "Production account ID"
}

output "shared_services_account_id" {
  value       = aws_organizations_account.shared_services.id
  description = "Shared services account ID"
}

output "account_ids" {
  value = {
    master     = aws_organizations_organization.main.master_account_id
    dev        = aws_organizations_account.dev.id
    staging    = aws_organizations_account.staging.id
    uat        = aws_organizations_account.uat.id
    production = aws_organizations_account.production.id
    shared     = aws_organizations_account.shared_services.id
  }
  description = "Map of all account IDs"
}

output "organizational_units" {
  value = {
    production     = aws_organizations_organizational_unit.production.id
    non_production = aws_organizations_organizational_unit.non_production.id
    shared         = aws_organizations_organizational_unit.shared.id
  }
  description = "Map of organizational unit IDs"
}

output "service_control_policies" {
  value = {
    cost_control       = aws_organizations_policy.cost_control.id
    region_restriction = aws_organizations_policy.region_restriction.id
  }
  description = "Map of service control policy IDs"
}
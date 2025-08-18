# Variables for AWS Organizations

variable "master_account_email" {
  description = "Email address for the master account"
  type        = string
}

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "diagnyx"
}

variable "dev_account_email" {
  description = "Email for development account"
  type        = string
}

variable "staging_account_email" {
  description = "Email for staging account"
  type        = string
}

variable "uat_account_email" {
  description = "Email for UAT account"
  type        = string
}

variable "prod_account_email" {
  description = "Email for production account"
  type        = string
}

variable "shared_account_email" {
  description = "Email for shared services account"
  type        = string
}

variable "budget_alert_email" {
  description = "Email for budget alerts"
  type        = string
}

variable "terraform_state_bucket" {
  description = "S3 bucket for terraform state"
  type        = string
}

variable "terraform_lock_table" {
  description = "DynamoDB table for terraform locks"
  type        = string
}
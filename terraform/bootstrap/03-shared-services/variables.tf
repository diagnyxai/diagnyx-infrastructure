# Variables for Shared Services Account

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Main domain name for the platform"
  type        = string
  default     = "diagnyx.ai"
}

variable "dev_account_id" {
  description = "Development account ID"
  type        = string
}

variable "staging_account_id" {
  description = "Staging account ID"
  type        = string
}

variable "uat_account_id" {
  description = "UAT account ID"
  type        = string
}

variable "prod_account_id" {
  description = "Production account ID"
  type        = string
}

variable "master_account_id" {
  description = "Master/Organization account ID"
  type        = string
}

variable "security_account_id" {
  description = "Security account ID"
  type        = string
}
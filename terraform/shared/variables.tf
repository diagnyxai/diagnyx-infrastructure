variable "aws_region" {
  description = "AWS region for shared resources"
  type        = string
  default     = "us-east-1"
}

variable "owner_email" {
  description = "Email of the infrastructure owner"
  type        = string
  default     = "infrastructure@diagnyx.ai"
}

variable "domain_name" {
  description = "Primary domain name for Route 53 hosted zone"
  type        = string
  default     = "diagnyx.ai"
}

variable "create_hosted_zone" {
  description = "Whether to create Route 53 hosted zone (set to true only once)"
  type        = bool
  default     = false
}
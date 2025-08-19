variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Primary domain name for Route 53 hosted zone"
  type        = string
  default     = "diagnyx.ai"
}

variable "create_hosted_zone" {
  description = "Whether to create Route 53 hosted zone"
  type        = bool
  default     = false  # Set to true only once to avoid conflicts
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}
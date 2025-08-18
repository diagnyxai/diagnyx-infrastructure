# Backend configuration for Development environment
bucket         = "diagnyx-terraform-state-development-123456789012"  # Replace with actual account ID
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "diagnyx-terraform-locks-development"

# Role to assume for state management (optional)
# role_arn = "arn:aws:iam::123456789012:role/TerraformStateRole"
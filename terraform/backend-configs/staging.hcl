# Backend configuration for Staging environment
bucket         = "diagnyx-terraform-state-staging-234567890123"  # Replace with actual account ID
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "diagnyx-terraform-locks-staging"

# Role to assume for state management (optional)
# role_arn = "arn:aws:iam::234567890123:role/TerraformStateRole"
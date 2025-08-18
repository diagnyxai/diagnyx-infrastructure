# Backend configuration for UAT environment
bucket         = "diagnyx-terraform-state-uat-345678901234"  # Replace with actual account ID
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "diagnyx-terraform-locks-uat"

# Role to assume for state management (optional)
# role_arn = "arn:aws:iam::345678901234:role/TerraformStateRole"
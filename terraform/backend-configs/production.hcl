# Backend configuration for Production environment
bucket         = "diagnyx-terraform-state-production-456789012345"  # Replace with actual account ID
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "diagnyx-terraform-locks-production"

# Role to assume for state management (required for production)
# role_arn = "arn:aws:iam::456789012345:role/TerraformStateRole"

# Additional security for production
# kms_key_id = "arn:aws:kms:us-east-1:456789012345:key/your-kms-key-id"
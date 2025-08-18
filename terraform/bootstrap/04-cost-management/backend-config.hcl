bucket         = "diagnyx-terraform-state-master"
key            = "bootstrap/cost-management/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "diagnyx-terraform-locks-master"
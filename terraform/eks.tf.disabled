# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = var.eks_cluster_version
  
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets
  
  # EKS Managed Node Group
  eks_managed_node_groups = {
    # On-demand node group for critical workloads
    on_demand = {
      desired_size = max(1, floor(var.eks_node_group_desired_size * 0.3))
      min_size     = 1
      max_size     = max(3, floor(var.eks_node_group_max_size * 0.3))
      
      instance_types = var.eks_node_instance_types
      capacity_type  = "ON_DEMAND"
      
      update_config = {
        max_unavailable_percentage = 33
      }
      
      labels = {
        Environment = var.environment
        NodeGroup   = "on-demand"
        WorkloadType = "critical"
      }
      
      taints = []
      
      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${local.name_prefix}-eks" = "owned"
        "CostOptimization" = "on-demand-baseline"
      }
    }
    
    # Spot instance node group for non-critical workloads
    spot = {
      desired_size = var.enable_spot_instances ? ceil(var.eks_node_group_desired_size * 0.7) : 0
      min_size     = var.enable_spot_instances ? 1 : 0
      max_size     = var.enable_spot_instances ? ceil(var.eks_node_group_max_size * 0.7) : 0
      
      instance_types = var.eks_spot_instance_types
      capacity_type  = "SPOT"
      
      update_config = {
        max_unavailable_percentage = 50
      }
      
      labels = {
        Environment = var.environment
        NodeGroup   = "spot"
        WorkloadType = "non-critical"
        InstanceLifecycle = "spot"
      }
      
      taints = [
        {
          key    = "spot-instance"
          value  = "true"
          effect = "NoSchedule"
        }
      ]
      
      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${local.name_prefix}-eks" = "owned"
        "CostOptimization" = "spot-instances"
      }
    }
    
    monitoring = {
      desired_size = 2
      min_size     = 1
      max_size     = 3
      
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      labels = {
        Environment = var.environment
        NodeGroup   = "monitoring"
        Workload    = "monitoring"
      }
      
      taints = [
        {
          key    = "monitoring"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
  
  # aws-auth configmap
  manage_aws_auth_configmap = true
  
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.eks_admin.arn
      username = "eks-admin"
      groups   = ["system:masters"]
    },
  ]
  
  tags = local.common_tags
}

# IAM Role for EKS Admin
resource "aws_iam_role" "eks_admin" {
  name = "${local.name_prefix}-eks-admin"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IRSA for cluster autoscaler
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  
  role_name = "${local.name_prefix}-cluster-autoscaler"
  
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
  
  tags = local.common_tags
}

# IRSA for AWS Load Balancer Controller
module "load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  
  role_name = "${local.name_prefix}-aws-load-balancer-controller"
  
  attach_load_balancer_controller_policy = true
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  
  tags = local.common_tags
}

# IRSA for External DNS
module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  
  role_name = "${local.name_prefix}-external-dns"
  
  attach_external_dns_policy = true
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
  
  tags = local.common_tags
}

# IRSA for Cert Manager
module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  
  role_name = "${local.name_prefix}-cert-manager"
  
  attach_cert_manager_policy = true
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }
  
  tags = local.common_tags
}
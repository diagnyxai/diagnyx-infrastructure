# Karpenter for Dynamic Node Provisioning
# Provides better cost optimization than static node groups

# Karpenter namespace
resource "kubernetes_namespace" "karpenter" {
  count = var.enable_karpenter ? 1 : 0
  
  metadata {
    name = "karpenter"
  }
}

# Karpenter Controller IAM Role (IRSA)
module "karpenter_irsa" {
  count = var.enable_karpenter ? 1 : 0
  
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  
  role_name = "${local.name_prefix}-karpenter-controller"
  
  attach_karpenter_controller_policy = true
  
  karpenter_controller_cluster_name       = module.eks.cluster_name
  karpenter_controller_node_iam_role_arns = [
    module.eks.eks_managed_node_groups["on_demand"].iam_role_arn,
    module.eks.eks_managed_node_groups["spot"].iam_role_arn
  ]
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
  
  tags = local.common_tags
}

# Install Karpenter using Helm
resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0
  
  namespace        = kubernetes_namespace.karpenter[0].metadata[0].name
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  
  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }
  
  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter[0].name
  }
  
  set {
    name  = "settings.aws.interruptionQueueName"
    value = aws_sqs_queue.karpenter_interruption[0].name
  }
  
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa[0].iam_role_arn
  }
  
  set {
    name  = "settings.aws.vmMemoryOverheadPercent"
    value = "0.075"  # Optimize memory allocation
  }
  
  depends_on = [
    module.eks,
    module.karpenter_irsa
  ]
}

# IAM Instance Profile for Karpenter Nodes
resource "aws_iam_instance_profile" "karpenter" {
  count = var.enable_karpenter ? 1 : 0
  
  name = "${local.name_prefix}-karpenter-node"
  role = aws_iam_role.karpenter_node[0].name
}

resource "aws_iam_role" "karpenter_node" {
  count = var.enable_karpenter ? 1 : 0
  
  name = "${local.name_prefix}-karpenter-node"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  
  tags = local.common_tags
}

# SQS Queue for Spot Interruption Handling
resource "aws_sqs_queue" "karpenter_interruption" {
  count = var.enable_karpenter ? 1 : 0
  
  name                      = "${local.name_prefix}-karpenter-interruption"
  message_retention_seconds = 300
  
  tags = local.common_tags
}

# EventBridge Rules for Spot Interruption
resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  count = var.enable_karpenter ? 1 : 0
  
  name        = "${local.name_prefix}-karpenter-spot-interruption"
  description = "Karpenter spot instance interruption warning"
  
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  count = var.enable_karpenter ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption[0].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption[0].arn
}

# Karpenter Provisioner Configuration
resource "kubectl_manifest" "karpenter_provisioner" {
  count = var.enable_karpenter ? 1 : 0
  
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "default"
    }
    spec = {
      # Resource limits
      limits = {
        resources = {
          cpu    = 1000
          memory = "1000Gi"
        }
      }
      
      # Requirements for instances
      requirements = [
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["spot", "on-demand"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["arm64", "amd64"]  # Support both architectures
        },
        {
          key      = "node.kubernetes.io/instance-type"
          operator = "In"
          values   = concat(
            var.eks_spot_instance_types,
            ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
          )
        }
      ]
      
      # Provider-specific configuration
      providerRef = {
        name = "default"
      }
      
      # Taints for spot instances
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NoSchedule"
        }
      ]
      
      # Deprovisioning settings for cost optimization
      ttlSecondsAfterEmpty = 30  # Quick scale-down
      
      # Labels
      labels = {
        "managed-by"       = "karpenter"
        "cost-optimized"   = "true"
        "environment"      = var.environment
      }
    }
  })
  
  depends_on = [helm_release.karpenter]
}

# Karpenter AWS Node Pool Configuration
resource "kubectl_manifest" "karpenter_node_pool" {
  count = var.enable_karpenter ? 1 : 0
  
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1alpha1"
    kind       = "AWSNodeInstanceProfile"
    metadata = {
      name = "default"
    }
    spec = {
      instanceProfile = aws_iam_instance_profile.karpenter[0].name
      
      # Subnet selection
      subnetSelector = {
        "karpenter.sh/discovery" = module.eks.cluster_name
      }
      
      # Security group selection
      securityGroupSelector = {
        "karpenter.sh/discovery" = module.eks.cluster_name
      }
      
      # Instance store for better performance
      instanceStorePolicy = "RAID0"
      
      # User data for node initialization
      userData = base64encode(templatefile("${path.module}/templates/karpenter-userdata.sh", {
        cluster_name        = module.eks.cluster_name
        cluster_endpoint    = module.eks.cluster_endpoint
        cluster_ca          = module.eks.cluster_certificate_authority_data
        enable_ssm          = true
      }))
      
      # AMI selection - use latest EKS optimized AMI
      amiFamily = "AL2"  # Amazon Linux 2
      
      # Block device mappings for cost optimization
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = "50Gi"  # Smaller root volume
            volumeType          = "gp3"   # Cheaper than gp2
            deleteOnTermination = true
          }
        }
      ]
      
      # Metadata options
      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 2
        httpTokens              = "required"  # IMDSv2 for security
      }
    }
  })
  
  depends_on = [helm_release.karpenter]
}

# Variables for Karpenter
variable "enable_karpenter" {
  description = "Enable Karpenter for dynamic node provisioning"
  type        = bool
  default     = true
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "v0.31.0"
}
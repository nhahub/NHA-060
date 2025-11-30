module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable public access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  # Enable IAM Roles for Service Accounts (required for EBS CSI Driver)
  enable_irsa = true

  cluster_enabled_log_types = ["api"]

  eks_managed_node_groups = {
    main = {
      name           = "main-nodegroup"
      instance_types = ["t3.small"]

      min_size     = 2
      max_size     = 2  
      desired_size = 2

      enable_monitoring = false
      disk_size = 8

      update_config = {
        max_unavailable_percentage = 50
      }

      tags = {
        Environment = "dev"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Required for Kubernetes provider
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Jenkins Namespace
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }

  depends_on = [module.eks]
}

# Jenkins Deployment
resource "kubernetes_deployment" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
  
  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "jenkins"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "jenkins"
        }
      }
      
      spec {
        container {
          name  = "jenkins"
          image = "jenkins/jenkins:lts"
          
          port {
            container_port = 8080
          }
          
          port {
            container_port = 50000
          }
          
          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }
          
          volume_mount {
            name       = "jenkins-data"
            mount_path = "/var/jenkins_home"
          }
        }
        
        volume {
          name = "jenkins-data"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [module.eks]
}

# Jenkins Service
resource "kubernetes_service" "jenkins" {
  metadata {
    name      = "jenkins-service"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
  
  spec {
    selector = {
      app = "jenkins"
    }
    
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
    
    port {
      name        = "agent"
      port        = 50000
      target_port = 50000
    }
    
    type = "LoadBalancer"
  }

  depends_on = [module.eks]
}

# EBS CSI Driver for persistent volumes - COMMENTED OUT FOR NOW
# resource "aws_eks_addon" "ebs_csi_driver" {
#   cluster_name = module.eks.cluster_name
#   addon_name   = "aws-ebs-csi-driver"
# }

# IAM policy for EBS CSI Driver - COMMENTED OUT FOR NOW
# resource "aws_iam_policy" "ebs_csi_policy" {
#   name        = "${var.cluster_name}-ebs-csi-policy"
#   description = "EBS CSI Driver policy for EKS cluster"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ec2:AttachVolume",
#           "ec2:CreateSnapshot",
#           "ec2:CreateTags",
#           "ec2:CreateVolume",
#           "ec2:DeleteSnapshot",
#           "ec2:DeleteTags",
#           "ec2:DeleteVolume",
#           "ec2:DescribeAvailabilityZones",
#           "ec2:DescribeInstances",
#           "ec2:DescribeSnapshots",
#           "ec2:DescribeTags",
#           "ec2:DescribeVolumes",
#           "ec2:DescribeVolumesModifications",
#           "ec2:DetachVolume",
#           "ec2:ModifyVolume"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# Attach EBS CSI policy to node group role - COMMENTED OUT FOR NOW
# resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attachment" {
#   policy_arn = aws_iam_policy.ebs_csi_policy.arn
#   role       = aws_iam_role.eks_nodes.name
# }
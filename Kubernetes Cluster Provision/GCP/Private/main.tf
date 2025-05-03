terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 1.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

locals {
  cluster_config = yamldecode(file("vars.yml"))
  platform_nodes = local.cluster_config.platform_nodes
  compute_nodes  = local.cluster_config.compute_nodes
  vectordb_nodes = local.cluster_config.vectordb_nodes
  region_az_mapping = {
    "us-east-1" = ["us-east-1a", "us-east-1b"],
    "us-east-2" = ["us-east-2a", "us-east-2b"],
    "us-west-1" = ["us-west-1a", "us-west-1b"],
    "us-west-2" = ["us-west-2a", "us-west-2b"],
    "af-south-1" = ["af-south-1a", "af-south-1b"],
    "ap-east-1" = ["ap-east-1a", "ap-east-1b"],
    "ap-south-2" = ["ap-south-2a", "ap-south-2b"],
    "ap-southeast-3" = ["ap-southeast-3a", "ap-southeast-3b"],
    "ap-southeast-4" = ["ap-southeast-4a", "ap-southeast-4b"],
    "ap-south-1" = ["ap-south-1a", "ap-south-1b"],
    "ap-northeast-3" = ["ap-northeast-3a", "ap-northeast-3b"],
    "ap-northeast-2" = ["ap-northeast-2a", "ap-northeast-2b"],
    "ap-southeast-1" = ["ap-southeast-1a", "ap-southeast-1b"],
    "ap-southeast-2" = ["ap-southeast-2a", "ap-southeast-2b"],
    "ap-northeast-1" = ["ap-northeast-1a", "ap-northeast-1b"],
    "ca-central-1" = ["ca-central-1a", "ca-central-1b"],
    "eu-central-1" = ["eu-central-1a", "eu-central-1b"],
    "eu-west-1" = ["eu-west-1a", "eu-west-1b"],
    "eu-west-2" = ["eu-west-2a", "eu-west-2b"],
    "eu-south-1" = ["eu-south-1a", "eu-south-1b"],
    "eu-west-3" = ["eu-west-3a", "eu-west-3b"],
    "eu-south-2" = ["eu-south-2a", "eu-south-2b"],
    "eu-north-1" = ["eu-north-1a", "eu-north-1b"],
    "eu-central-2" = ["eu-central-2a", "eu-central-2b"],
    "me-south-1" = ["me-south-1a", "me-south-1b"],
    "me-central-1" = ["me-central-1a", "me-central-1b"],
    "il-central-1" = ["il-central-1a", "il-central-1b"],
    "sa-east-1" = ["sa-east-1a", "sa-east-1b"]
  }
}

# Configure the AWS provider using variables
provider "aws" {
    region = local.cluster_config.aws_region
}

# Create IAM role for EKS cluster
resource "aws_iam_role" "eks-iam-role" {
  name = "katonic-cluster-role-${local.cluster_config.random_value}"  
  tags = {
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Attach policies to the IAM Role
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
 role    = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
 policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
 role    = aws_iam_role.eks-iam-role.name
}

# Create the EKS Cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "20.20.0"
  cluster_name = "${local.cluster_config.cluster_name}-${local.cluster_config.random_value}" 
  cluster_version = local.cluster_config.eks_version 
  create_iam_role = false 
  iam_role_arn = aws_iam_role.eks-iam-role.arn
  create_kms_key = false
  cluster_encryption_config = {}
  vpc_id  = local.cluster_config.vpc_id
  subnet_ids = [local.cluster_config.subnet_1_id, local.cluster_config.subnet_2_id]
  create_cloudwatch_log_group = false
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true
  authentication_mode = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  tags = {
    unique-id = "katonic-${local.cluster_config.random_value}"
    "url" = local.cluster_config.katonic_domain_prefix
  }
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
  }
}

# Create IAM Role for Worker Nodes
resource "aws_iam_role" "workernodes" {
  name = "Katonic-Node-Group-Role-${local.cluster_config.random_value}"
  tags = {
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach Policy to IAM Role 
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role    = aws_iam_role.workernodes.name
}
 
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role    = aws_iam_role.workernodes.name
}
  
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role    = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AWSAppMeshFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSAppMeshFullAccess"
  role       = aws_iam_role.workernodes.name
}

resource "aws_launch_template" "platform-template" {
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_type = "gp3"
      volume_size = local.platform_nodes.os_disk_size
    }
  }
}

resource "aws_launch_template" "compute-template" {
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_type = "gp3"
      volume_size = local.compute_nodes.os_disk_size
    }
  }
}

resource "aws_launch_template" "vectordb-template" {
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_type = "gp3"
      volume_size = local.vectordb_nodes.os_disk_size
    }
  }
}

# Create platform worker node group
resource "aws_eks_node_group" "platform_node_group" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "platform"
  node_role_arn = aws_iam_role.workernodes.arn
  subnet_ids = [local.cluster_config.subnet_1_id, local.cluster_config.subnet_2_id]
  capacity_type   = "ON_DEMAND"
  instance_types = [local.platform_nodes.instance_type] 
  scaling_config {
    desired_size = local.platform_nodes.min_count 
    max_size     = local.platform_nodes.max_count 
    min_size     = local.platform_nodes.min_count 
  }
  launch_template {
    id = aws_launch_template.platform-template.id
    version = "$Latest"
  }
  update_config {
    max_unavailable = 1
  }
  labels = {
    "katonic.ai/node-pool" = "platform"
  }
  taint {
    key    = "katonic.ai/node-pool"
    value  = "platform"
    effect = "NO_SCHEDULE"
  }
  tags = {
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

# Create compute worker node group
resource "aws_eks_node_group" "compute_node_group" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "compute"
  node_role_arn = aws_iam_role.workernodes.arn
  subnet_ids = [local.cluster_config.subnet_1_id, local.cluster_config.subnet_2_id]
  capacity_type   = "ON_DEMAND"
  instance_types = [local.compute_nodes.instance_type]
  scaling_config {
    desired_size = local.compute_nodes.min_count 
    max_size     = local.compute_nodes.max_count 
    min_size     = local.compute_nodes.min_count 
  }
  launch_template {
    id = aws_launch_template.compute-template.id
    version = "$Latest"
  }
  update_config {
    max_unavailable = 1
  }
  labels = {
    "katonic.ai/node-pool" = "compute"
  }
  tags = {
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

# Create vectordb worker node group
resource "aws_eks_node_group" "vectordb_node_group" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "vectordb"
  node_role_arn   = aws_iam_role.workernodes.arn
  subnet_ids      = [local.cluster_config.subnet_1_id, local.cluster_config.subnet_2_id]
  capacity_type   = "ON_DEMAND"
  instance_types  = [local.vectordb_nodes.instance_type]

  scaling_config {
    desired_size = local.vectordb_nodes.min_count
    max_size     = local.vectordb_nodes.max_count
    min_size     = local.vectordb_nodes.min_count
  }

  launch_template {
    id      = aws_launch_template.vectordb-template.id
    version = "$Latest"
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "katonic.ai/node-pool" = "vectordb"
  }

  taint {
    key    = "katonic.ai/node-pool"
    value  = "vectordb"
    effect = "NO_SCHEDULE"
  }

  tags = {
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}
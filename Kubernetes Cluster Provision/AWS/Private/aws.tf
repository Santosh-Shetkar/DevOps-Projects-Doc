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
  cluster_config = yamldecode(file("vars.yml")) # CHANGE PATH
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

# Create the VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.10.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}" 
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

# Create public subnets
resource "aws_subnet" "public_subnet_2a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.10.0.0/20"
  availability_zone       = local.region_az_mapping[local.cluster_config.aws_region][0]  
  map_public_ip_on_launch = true
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}-Public-Subnet-(AZ1)"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

resource "aws_subnet" "public_subnet_2b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.10.16.0/20"
  availability_zone       = local.region_az_mapping[local.cluster_config.aws_region][1] 
  map_public_ip_on_launch = true
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}-Public-Subnet-(AZ2)"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

# Create private subnets
resource "aws_subnet" "private_subnet_2a" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.10.32.0/20"
  availability_zone = local.region_az_mapping[local.cluster_config.aws_region][0]
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}-Private-Subnet-(AZ1)"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

resource "aws_subnet" "private_subnet_2b" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.10.48.0/20"
  availability_zone = local.region_az_mapping[local.cluster_config.aws_region][1]
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}-Private-Subnet-(AZ2)"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "katonic-ig-${local.cluster_config.random_value}"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

# Create EIP for NAT gateway
resource "aws_eip" "eks_eip" {
  domain = "vpc"
}

# Create NAT gateway
resource "aws_nat_gateway" "eks_nat_gw" {
  allocation_id = aws_eip.eks_eip.id
  subnet_id     = aws_subnet.public_subnet_2a.id
  tags = {
    Name = "katonic-nat-gateway-${local.cluster_config.random_value}"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
}

# Create public route table and associate it with public subnets   
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}-Public-Routes"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }
}

resource "aws_route_table_association" "public_subnet_2a_association" {
  subnet_id      = aws_subnet.public_subnet_2a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2b_association" {
  subnet_id      = aws_subnet.public_subnet_2b.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create private route table and associate them with private subnets
resource "aws_route_table" "private_route_table_A" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}-Private-Route-A"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gw.id
  }
}

resource "aws_route_table_association" "private_subnet_2a_association" {
  subnet_id      = aws_subnet.private_subnet_2a.id
  route_table_id = aws_route_table.private_route_table_A.id
}

resource "aws_route_table" "private_route_table_B" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "katonic-vpc-${local.cluster_config.random_value}-Private-Route-B"
    unique-id = "katonic-${local.cluster_config.random_value}"
  }
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gw.id
  }
}

resource "aws_route_table_association" "private_subnet_2b_association" {
  subnet_id      = aws_subnet.private_subnet_2b.id
  route_table_id = aws_route_table.private_route_table_B.id
}

# Create security group for jump server
resource "aws_security_group" "jump_server_security_group" {
  name        = "katonic-jump-sever-sg-${local.cluster_config.random_value}"
  description = "Security group for the jump server"
  vpc_id      = aws_vpc.eks_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "jump_server" {
    ami = local.cluster_config.ami
    instance_type = "t3.medium"
    key_name = local.cluster_config.ec2_key_name
    subnet_id     = aws_subnet.public_subnet_2b.id
    associate_public_ip_address = true
    tags = {
    Name = "jump-server-${local.cluster_config.random_value}"
    }
    vpc_security_group_ids = [aws_security_group.jump_server_security_group.id]

    connection {
    type        = "ssh"
    user        = "ubuntu"  # Specify the SSH user for your AMI
    private_key = file("${local.cluster_config.ec2_key_name}.pem")
    host        = self.public_ip
    }
    provisioner "remote-exec" {
      inline = [
        "sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.28.8/bin/linux/amd64/kubectl",
        "sudo chmod +x ./kubectl",
        "sudo cp ./kubectl /usr/bin/kubectl",
        "sudo mv ./kubectl /usr/local/bin/kubectl",
        "sudo apt update",
        "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common",
        "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
        "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu  focal stable\" | sudo tee /etc/apt/sources.list.d/docker.list",
        "sudo apt update",
        "sudo apt install docker-ce -y",
        "sudo systemctl start docker",
        "sudo systemctl enable docker",
        "sudo apt update",
        "sudo apt install python3-pip -y",
        "sudo pip3 install awscli",
        "aws --version",
        "sudo curl --silent --location \"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz\" | sudo tar xz -C /usr/local/bin",      
        "eksctl version"
      ]
    }
    root_block_device {
      volume_type = "gp3"
      volume_size = 60
    }
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id              = aws_vpc.eks_vpc.id
  service_name        = "com.amazonaws.${local.cluster_config.aws_region}.s3"
  vpc_endpoint_type   = "Gateway"
}

resource "aws_vpc_endpoint_route_table_association" "private_route_table_association_A" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
  route_table_id  = aws_route_table.private_route_table_A.id
}

resource "aws_vpc_endpoint_route_table_association" "private_route_table_association_B" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
  route_table_id  = aws_route_table.private_route_table_B.id
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg-${local.cluster_config.random_value}"
  description = "Security group for EFS endpoint"
  vpc_id      = aws_vpc.eks_vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "efs_endpoint" {
  vpc_id              = aws_vpc.eks_vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${local.cluster_config.aws_region}.elasticfilesystem"
  security_group_ids = [aws_security_group.efs_sg.id]  
  subnet_ids = [
    aws_subnet.private_subnet_2a.id,
    aws_subnet.private_subnet_2b.id
  ]
}
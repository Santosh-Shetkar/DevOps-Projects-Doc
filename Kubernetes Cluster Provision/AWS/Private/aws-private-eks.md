# Terraform AWS Infrastructure and Private EKS HA Cluster Setup

This repository provides a Terraform configuration (`aws.tf`) to provision foundational AWS infrastructure for hosting a **Private EKS Cluster**. The setup includes a custom VPC, public and private subnets, NAT Gateway, route tables, and a bastion (jump) server.

---

## 📁 Files

- `aws.tf`: Main Terraform configuration for provisioning networking and compute resources.
- `vars.yml`: A YAML file for input variables like AWS region, AMI ID, and EC2 key pair name.

---

## 🔧 Prerequisites

- Terraform installed (`>=1.0`)
- AWS CLI configured (`aws configure`)
- SSH key pair created in AWS (`.pem` file required locally)
- Proper IAM permissions to create VPC, EC2, NAT, Subnets, Endpoints, etc.

---

## ✍️ Step-by-Step Usage

### 1. Configure `vars.yml`

Edit the `vars.yml` file to define required values:

```yaml
# vars.yml
aws_region: us-east-2
random_value: abcabc
ami: ami-0b4750268a88e78e0  # Region-specific AMI ID
ec2_key_name: aws-testing-private  # Key name without .pem extension
```

### 2. Initialize and Apply Terraform
```
terraform init
terraform apply -var-file=vars.yml
```

📦 What Gets Created
VPC with DNS support

- 2 Public Subnets and 2 Private Subnets (spread across AZs)
- Internet Gateway for public traffic
- NAT Gateway and Elastic IP for private subnet outbound traffic
- Route Tables for public and private networking
- VPC Endpoints
    - S3 (Gateway type)
    - EFS (Interface type)
- Security Groups for jump server and EFS
- EC2 Jump Server (Bastion host) with:
    - kubectl, docker, awscli, and eksctl installed via remote-exec
    - Public IP for SSH access

🔐 Accessing the Jump Server
After apply, you can SSH into the jump server:
```
ssh -i aws-testing-private.pem ubuntu@<public-ip>
```

Use the .pem key corresponding to the name in vars.yml.

Now after accessing the jump server setup EKS cluster by following below instructions

## Terraform EKS Cluster Deployment Guide

This guide explains how to configure and deploy an Amazon EKS (Elastic Kubernetes Service) cluster using Terraform. All cluster-specific variables are managed via the eks-vars.yml file, and the infrastructure is provisioned using the aws-eks.tf configuration.

📁 File Structure

├── eks-vars.yml    # Cluster configuration variables

└── aws-eks.tf      # Terraform module and resource definitions

🔧 Prerequisites

Terraform ≥ 1.0.x installed.

AWS CLI configured (aws configure).

IAM permissions to create EKS, VPC, Subnets, IAM Roles, Node Groups, etc.

kubectl and aws-iam-authenticator installed locally or on the jump host for post-deployment access.

✍️ Step 1: Configure eks-vars.yml

Populate the following file with your desired cluster settings:

Note: Ensure that cluster_name is under 30 characters and that if private_cluster: True, you supply vpc_id, subnet_1_id, subnet_2_id, and jump_server_name.

🚀 Step 2: Deploy the EKS Cluster

From within the jump host (or your local environment if configured):

Initialize Terraform

```
terraform init
```
Apply the configuration
```
terraform apply -var-file=eks-vars.yml
```

Review the plan and confirm to proceed.

Terraform will:

    - Create a new VPC (if not using an existing one for a public cluster).
    - Provision public subnets, an Internet Gateway, and route tables.
    - Create IAM roles for the control plane and worker nodes.
    - Deploy the EKS control plane via the AWS EKS module.
    - Configure managed node groups (platform, compute, deployment, vectordb).
    - Optionally create GPU node groups if enabled.
    - Update your kubeconfig to access the new cluster.

Verify the cluster:
```
kubectl get nodes
```

📦 What Gets Created

- VPC (10.0.0.0/16) with DNS support and hostnames enabled.

- Two public subnets (AZ1 and AZ2).

- Internet Gateway and Public Route Table for external connectivity.

- IAM Roles:
    - eks-iam-role for the EKS control plane.
    - workernodes role for node groups with required policies.

- EKS Cluster:
    - Managed by terraform-aws-modules/eks/aws.
    - Endpoint public access (unless private_cluster: True).

- Node Groups (ON_DEMAND):
    - platform, compute, deployment, vectordb.
    - Auto-scaling configured based on min_count/max_count.
    - Taints and labels assigned per pool.

- Automatic kubeconfig update via a null_resource and local-exec.

🔄 Cleanup

To destroy all resources created by this configuration:
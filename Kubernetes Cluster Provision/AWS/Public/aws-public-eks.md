# Terraform AWS Infrastructure and EKS HA Cluster Setup

✅ Pre-Requisites
1. Terraform Installed: Version 1.0 or higher.
2. AWS CLI Configured: You must run aws configure to set up your credentials (Access Key, Secret Key, and Region).
3. IAM Permissions: Your IAM user/role must have permissions to create EKS, VPC, Subnets, IAM Roles, etc.
4. YAML File: A properly structured vars.yml file in the same directory that defines:
    - aws_region, random_value, cluster_name, eks_version, etc.
    - Node group configurations like:
```
        platform_nodes:
        instance_type: t3.medium
        os_disk_size: 30
        min_count: 1
        max_count: 2
        compute_nodes:
        instance_type: t3.large
        os_disk_size: 40
        min_count: 2
        max_count: 4
        vectordb_nodes:
        instance_type: t3.xlarge
        os_disk_size: 100
        min_count: 1
        max_count: 3
```

## 🚀 Steps to Deploy

1. **Navigate to the Terraform project directory**:

```bash
cd /path/to/your/terraform/project
```

2. **Initialize Terraform**:

```bash
terraform init
```

3. **Validate Terraform code**:

```bash
terraform validate
```

4. **Review the Terraform execution plan**:

```bash
terraform plan
```

5. **Apply Terraform to create the infrastructure**:

```bash
terraform apply
```

You will be prompted to confirm with `yes`.

6. **Optional: Save apply output to a log file**:

```bash
terraform apply -auto-approve > apply-log.txt
```

---

## 🧹 To Destroy the Setup

To clean up and destroy the resources created:

```bash
terraform destroy
```

---

## 📘 Notes

- Ensure your `vars.yml` is correctly structured and placed.
- You can customize node groups (platform, compute, vectordb) as per your workload.



# Terraform AWS Infrastructure and EKS HA Cluster Setup

✅ Pre-Requisites
1. Terraform Installed: Version 1.0 or higher.
2. Azure CLI Configured: You must run aws configure to set up your credentials (Access Key, Secret Key, and Region).
3. YAML File: A properly structured vars.yml file in the same directory that defines:
```
aks_pricing_tier: Standard                                     #Free / Standard / Premium
kubernetes_version: 1.30.11    #1.30.6                             #Supported Versions are 1.28.x

cluster_name: katonic-platform-v6-0               #Cluster name must be less than 30 characters.

resource_group_name: 
resource_group_location: 
azure_subscription_id: 

vnet_name: 
aks_subnet_name:

compute_nodes:
  instance_type: Standard_D8s_v3                        #Default # If you are deploying resources in the Central India region, consider utilizing the D8ads_v5 instance_type for its cost efficiency.
  min_count: 1                                          #minimum 1 recommended
  max_count: 4
  os_disk_size: 128

platform_nodes:
  instance_type: Standard_DS3_v2                        #Default # If you are deploying resources in the Central India region, consider utilizing the D8ads_v5 instance_type for its cost efficiency.
  min_count: 2                                          #minimum 2 recommended
  max_count: 4        
  os_disk_size: 128

vectordb_nodes:
  instance_type: Standard_DS3_v2                        #Default # If you are deploying resources in the Central India region, consider utilizing the D8ads_v5 instance_type for its cost efficiency.
  min_count: 1                                          #minimum 1 recommended
  max_count: 4
  os_disk_size: 128
  
deployment_nodes:
  instance_type: Standard_D8s_v3                        #Default # If you are deploying resources in the Central India region, consider utilizing the D8ads_v5 instance_type for its cost efficiency.
  min_count: 1                                          #minimum 1 recommended
  max_count: 4
  os_disk_size: 128

#GPU
gpu_enabled: False                                      #It is mandatory to set enable_gpu_workspace to True when you want to use GPU Workspaces
gpu_nodes:
  instance_type: Standard_NC6s_v3                       #Default
  gpu_type: "none"                                      #Enter the type of GPU available on machine. eg. v100,k80,a100,a10g
  min_count: 1                                          #minimum 1 recommended if gpu_enabled: True
  max_count: 4
  os_disk_size: 512
  gpu_vRAM: 
  gpus_per_node:
enable_gpu_workspace: False
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



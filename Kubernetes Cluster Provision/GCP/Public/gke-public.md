# Private GKE Cluster Setup using Terraform

This setup involves for deploying a GKE (Google Kubernetes Engine) cluster:

1. **Network Infrastructure Setup** – VPC, Subnet
2. **GKE Cluster and Node Pools Deployment** – Using a YAML-based dynamic configuration

---


## Step 1: Deploy GKE Cluster & Node Pools

Apply your main.tf which contains the GKE cluster and multiple custom node pools like compute, platform, and vectordb.

Make sure your main.tf dynamically reads from a vars.yml configuration.

main.tf Highlights
- Uses yamldecode(file("vars.yml")) to pull values.
- Configures:

    - Private GKE Cluster (enable_private_nodes = true)
    - Multiple node pools with autoscaling
    - Calico Network Policy
    - Enterprise Tier settings
    - Workload Identity enabled
    - Ensure vars.yml updated with your configuration:

```
mkdir gke
cd gke

vim main.tf
(copy and paste)

terraform init
terraform apply -auto-approve
```
# Private GKE Cluster Setup using Terraform

This setup involves a **two-step process** for deploying a private GKE (Google Kubernetes Engine) cluster:

1. **Network Infrastructure Setup** – VPC, Subnet, Router, and Cloud NAT
2. **GKE Cluster and Node Pools Deployment** – Using a YAML-based dynamic configuration

---

## Step 1: Run Initial Infrastructure Setup

Create the network layer for your GKE private cluster. Use the following Terraform configuration to deploy:

### `network.tf`
```
mkdir gcp-private
cd gcp-private
vim network.tf
(copy paste code )

terraform init
terraform apply -auto-approve
```


## Step 2: Deploy GKE Cluster & Node Pools

After networking setup is done, apply your main.tf which contains the GKE private cluster and multiple custom node pools like compute, platform, GPU, and vectordb.

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
# Ceph 1.16 Cluster Installation with Rook

## Default Ceph Cluster Installation

### Step-by-Step Instructions

#### Step 1: Install Monitoring Resources

```bash
kubectl create -f monitoring/rbac.yaml
kubectl create -f monitoring/localrules.yaml
```
#### Step 2: Deploy the Operator
```bash
kubectl apply -f operator.yaml
kubectl get pod -n rook-ceph
```
Wait for the operator pod to be in a Running state.

#### Step 3: Deploy the Ceph Cluster
```bash
kubectl apply -f cluster.yaml
watch kubectl get pod -n rook-ceph
```
Note: This step may take up to 10 minutes.

#### Step 4: Deploy the Ceph Filesystem
```bash
kubectl apply -f filesystem.yaml
watch kubectl get pod -n rook-ceph
```
#### Step 5: Create the Default Storage Class
```bash
kubectl apply -f csi/cephfs/storageclass.yaml
kubectl get sc
```
#### Step 6: Test the Storage Class
```bash
kubectl apply -f csi/cephfs/pod.yaml
kubectl apply -f csi/cephfs/pvc.yaml
```
Ceph Cluster Installation with Erasure Coding (EC)
Prerequisites
Ensure you have at least M + N machines if using the host as the failure domain.

### Step-by-Step Instructions

#### Step 1: Clone the Repository
```bash
git clone https://github.com/raj-katonic/rook-ceph.git
cd rook-ceph/deploy/examples
```

#### Step 2: Install CRDs and Common Resources
```bash
kubectl create -f crds.yaml
kubectl create -f common.yaml
```
#### Step 3: (Optional) Enable Monitoring
```bash
kubectl create -f monitoring/crds/
kubectl create -f monitoring/rbac.yaml
kubectl create -f monitoring/localrules.yaml
```
#### Step 4: Deploy the Operator
```bash
kubectl apply -f operator.yaml
watch kubectl get pod -n rook-ceph
```
#### Step 5: Deploy the Ceph Cluster
```bash
kubectl apply -f cluster.yaml
watch kubectl get pod -n rook-ceph
```
Wait until all pods are in Running state (may take ~10 minutes).

Step 6: Edit and Apply Erasure Coded Filesystem
Edit filesystem-ec.yaml to define dataPool options as per your storage efficiency needs.

Common M:N Erasure Coding Ratios

#	Ratio (M:N)	Storage Efficiency	Example
1	3:2	+66.66%	10GB → 16.66GB
2	2:1	+50%	10GB → 15GB
3	4:2	+50%	10GB → 15GB
4	5:1	+20%	10GB → 12GB

```bash
kubectl apply -f filesystem-ec.yaml
watch kubectl get pod -n rook-ceph
```
#### Step 7: Create Erasure Coding StorageClass
```bash
kubectl apply -f csi/cephfs/storageclass-ec.yaml
kubectl get sc
```
#### Step 8: Test the Erasure Coding StorageClass
```bash
kubectl apply -f csi/cephfs/pod.yaml
kubectl apply -f csi/cephfs/pvc.yaml

Ceph Troubleshooting
General Health Checks
```bash
ceph health detail
ceph -s
HEALTH_OK – Cluster is healthy

HEALTH_WARN – Temporary issue; monitor the state

HEALTH_ERR – Serious issue; requires immediate attention
```

### Common Issues & Reference Docs

#### MON
- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-monitors#monitor-is-out-of-quorum

- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-monitors#clock-skew

- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-monitors#the-monitor-store-is-getting-too-big

#### OSD
- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-osds#full-osds

- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-osds#nearfull-osds

- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-osds#osds-are-down

- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-osds#osds-are-down

- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-osds#flapping-osds

- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-osds#slow-requests-and-requests-are-blocked

#### PG
- https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/2/html/troubleshooting_guide/troubleshooting-placement-groups#doc-wrapper
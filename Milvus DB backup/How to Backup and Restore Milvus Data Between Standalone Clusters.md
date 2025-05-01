# Milvus Backup and Restore Between Two Standalone Clusters

This guide documents the process of taking a backup from a Milvus instance in the **first standalone cluster** and restoring it to a **second standalone cluster**, using MinIO and AWS S3 as intermediary storage.

---

## 🧱 First Standalone Cluster – Backup Procedure

### 1. Create Pod in `vector-db` Namespace

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: milvus-backup-pod
  namespace: vector-db
spec:
  containers:
    - name: python-container
      image: python:3.8
      command: ["sleep", "infinity"]
```

```bash
kubectl exec -it milvus-backup-pod -n vector-db -- bash
```

### 2. Install Tools Inside the Pod

```bash
apt-get update
pip install milvus-cli
apt-get install vim -y
```

### 3. Create Milvus Connection Script

```bash
vim connect-milvus.py
```

Paste the following:

```python
from pymilvus import connections, utility

connections.connect(
    alias="default",
    host='prod-milvus-milvus.vector-db.svc.cluster.local',
    port='19530'
)

try:
    collections = utility.list_collections()
    print("Successfully connected to Milvus. Collections:")
    for collection in collections:
        print(f"- {collection}")
except Exception as e:
    print(f"Failed to connect to Milvus: {e}")
```

Run it:

```bash
python3 connect-milvus.py
```

### 4. Install Go, Git, and Clone Milvus Backup Tool

```bash
apt-get update
apt install git wget -y
wget https://go.dev/dl/go1.21.4.linux-amd64.tar.gz -O go.tar.gz
tar -xzvf go.tar.gz -C /usr/local
echo 'export PATH=$HOME/go/bin:/usr/local/go/bin:$PATH' >> ~/.profile
source ~/.profile
go version

git clone https://github.com/zilliztech/milvus-backup.git
cd milvus-backup
go get
go build
```

### 5. Configure Backup

```bash
cd configs/
vim backup.yaml
```

Paste configuration (with real values):

```yaml
log:
  level: info
  console: true
  file:
    rootPath: "logs/backup.log"

http:
  simpleResponse: true

milvus:
  address: prod-milvus-milvus.vector-db.svc.cluster.local
  port: 19530
  authorizationEnabled: false
  tlsMode: 0
  user: "username"
  password: "password"

minio:
  storageType: "minio"
  address: prod-milvus-minio.vector-db.svc.cluster.local
  port: 9000
  accessKeyID: minioadmin
  secretAccessKey: minioadmin
  useSSL: false
  useIAM: false
  iamEndpoint: ""
  bucketName: "prod-milvus"
  rootPath: "files"
  backupBucketName: "prod-milvus-new"
  backupRootPath: "backup"

backup:
  maxSegmentGroupSize: 6G
  parallelism:
    backupCollection: 4
    copydata: 128
    restoreCollection: 2
  keepTempFiles: false
  gcPause:
    enable: false
    seconds: 7200
    address: http://prod-milvus-milvus.vector-db.svc.cluster.local:9091
```

### 6. Run Backup

```bash
cd ..
./milvus-backup create -n prod_milvus_new
```

### 7. Verify Backup in MinIO

```bash
apt install wget -y
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc /usr/local/bin/

mc alias set myminio http://prod-milvus-minio.vector-db.svc.cluster.local:9000 minioadmin minioadmin
mc ls myminio
```

### 8. Copy to AWS S3

```bash
mc alias set s3 https://s3.us-east-2.amazonaws.com AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
mc mirror myminio/prod-milvus-new s3/prod-milvus-new
```

---

## 🛋️ Second Standalone Cluster – Restore Procedure

### 1. Create Pod in `vector-db` Namespace

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: milvus-backup-restore-pod
  namespace: vector-db
spec:
  containers:
    - name: ubuntu-container
      image: ubuntu:20.04
      command: ["sleep", "infinity"]
      securityContext:
        runAsUser: 0
        runAsGroup: 0
```

```bash
kubectl exec -it milvus-backup-restore-pod -n vector-db -- bash
```

### 2. Install Tools

```bash
apt-get update
apt-get install pip vim -y
pip install milvus-cli
```

### 3. Create and Run Milvus Connect Script

Same script as above (`connect-milvus.py`), test connection.

### 4. Set Up MinIO and Copy from S3

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc /usr/local/bin/

mc alias set myminio http://prod-milvus-minio.vector-db.svc.cluster.local:9000 minioadmin minioadmin
mc mb myminio/prod-milvus-new

mc alias set s3 https://s3.us-east-2.amazonaws.com AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
mc mirror s3/prod-milvus-new myminio/prod-milvus-new
```

### 5. Clone Milvus Backup Tool and Configure Restore

Same steps to install Go and clone repo.

Update `configs/backup.yaml` as above (same config file with backupBucketName set to `prod-milvus-new`).

### 6. Run Restore

```bash
cd ..
./milvus-backup restore -n prod_milvus_new
```

### 7. Verify Restoration

```bash
python3 connect-milvus.py
```

Compare collection names with the source cluster to ensure successful restoration.

---

## ✅ Result

- Collections from the **first standalone cluster** should now be available in the **second standalone cluster**.
- Verified via Python script and optionally via Milvus UI.


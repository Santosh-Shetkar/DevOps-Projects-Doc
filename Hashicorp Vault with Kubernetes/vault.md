# 🔐 HashiCorp Vault on Kubernetes with Helm

This guide walks you through deploying **HashiCorp Vault** on Kubernetes using Helm, enabling High Availability with Raft storage, exposing the Vault UI, configuring Kubernetes authentication, and storing/retrieving secrets.

---

## 📦 Prerequisites

- A running Kubernetes cluster (min 3 nodes recommended for HA)
- `kubectl` installed and configured
- `helm` installed
- `jq` installed (for JSON parsing)
- Base64 and curl utilities

---

## 🚀 Install Vault using Helm

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "ui.enabled=true" \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.dataStorage.enabled=true" \
  --set "server.dataStorage.size=10Gi" \
  --set "server.ha.raft.enabled=true"
```

🌐 Expose Vault UI

```bash
kubectl patch svc vault-ui -n vault -p '{"spec": {"type": "NodePort"}}'
```

🧩 Initialize Vault
```bash
kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1
```

🔓 Unseal Vault

```bash
kubectl exec -it vault-0 -n vault -- vault operator unseal <UNSEAL_KEY>
```

Join and unseal other pods:
```bash
kubectl exec -it vault-1 -n vault -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -it vault-2 -n vault -- vault operator raft join http://vault-0.vault-internal:8200

kubectl exec -it vault-1 -n vault -- vault operator unseal <UNSEAL_KEY>
kubectl exec -it vault-2 -n vault -- vault operator unseal <UNSEAL_KEY>
```
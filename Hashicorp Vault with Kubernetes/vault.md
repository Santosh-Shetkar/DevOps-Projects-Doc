# Installing and Configuring HashiCorp Vault in Kubernetes

This guide provides step-by-step instructions for installing, configuring, and using HashiCorp Vault in a Kubernetes cluster using Helm.

## Prerequisites

* A running Kubernetes cluster.
* `kubectl` configured to interact with your cluster.
* Helm v3 installed.

## 1. Installation

First, add the HashiCorp Helm repository and update your local repository information.

```bash
helm repo add hashicorp [https://helm.releases.hashicorp.com](https://helm.releases.hashicorp.com)
helm repo update
Now, install Vault using the Helm chart. This command installs Vault in High Availability (HA) mode with 3 replicas, enables the UI, and configures Raft integrated storage.helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "ui.enabled=true" \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.dataStorage.enabled=true" \
  --set "server.dataStorage.size=10Gi" \
  --set "server.ha.raft.enabled=true"
Configuration Explained:--namespace vault --create-namespace: Installs Vault into the vault namespace, creating it if it doesn't exist.--set "ui.enabled=true": Enables the Vault web UI.--set "server.ha.enabled=true": Enables High Availability (HA) mode.--set "server.ha.replicas=3": Sets the number of Vault server replicas to 3 for HA. Requires at least 3 Kubernetes nodes for optimal distribution.--set "server.dataStorage.enabled=true": Enables persistent storage for Vault data.--set "server.dataStorage.size=10Gi": Allocates 10Gi of persistent storage.--set "server.ha.raft.enabled=true": Enables the Raft consensus algorithm for integrated storage, required for HA mode without an external backend like Consul.2. Exposing Vault UI (Optional)To access the Vault UI from outside the cluster, you can change the vault-ui service type to NodePort or configure an Ingress controller. Using NodePort is simpler for testing:kubectl patch svc vault-ui -n vault -p '{"spec": {"type": "NodePort"}}'
Find the assigned NodePort and access the UI via http://<node-ip>:<node-port>.3. Initializing VaultInitialize Vault to generate the unseal keys and the initial root token. This command initializes Vault with a single unseal key.kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1
Important: Securely store the Unseal Key and the Initial Root Token displayed in the output. You will need them.(Note: By default, vault operator init uses 5 key shares and a threshold of 3. The command above simplifies this for demonstration purposes.)4. Unsealing VaultVault starts in a sealed state. Use the unseal key obtained from the previous step to unseal the primary Vault pod (vault-0):# Replace <unseal-key> with your actual unseal key
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key>
5. Joining HA Cluster NodesThe other Vault pods (vault-1, vault-2) need to join the Raft cluster led by vault-0.kubectl exec -it vault-1 -n vault -- vault operator raft join [http://vault-0.vault-internal:8200](http://vault-0.vault-internal:8200)
kubectl exec -it vault-2 -n vault -- vault operator raft join [http://vault-0.vault-internal:8200](http://vault-0.vault-internal:8200)
6. Unsealing HA NodesUnseal the remaining Vault pods using the same unseal key:# Replace <unseal-key> with your actual unseal key
kubectl exec -it vault-1 -n vault -- vault operator unseal <unseal-key>
kubectl exec -it vault-2 -n vault -- vault operator unseal <unseal-key>
7. Verifying Cluster StatusCheck if all nodes have joined the Raft cluster successfully:kubectl exec -it vault-0 -n vault -- vault operator raft list-peers
You should see all three pods listed as peers.8. Logging into VaultLog in to Vault using the initial root token generated during initialization:# Replace <root-token> with your actual root token
kubectl exec -it vault-0 -n vault -- vault login <root-token>
9. Enabling Secrets EnginesEnable the KV (Key-Value) version 2 secrets engine. This engine allows storing arbitrary secrets and supports versioning.kubectl exec -it vault-0 -n vault -- vault secrets enable kv-v2
10. Configuring Kubernetes AuthenticationEnable the Kubernetes authentication method, allowing applications within Kubernetes to authenticate with Vault using their Service Account tokens.kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes
Configure the Kubernetes auth method with the cluster's API server details and credentials. Vault needs these to verify service account tokens presented by applications.# Configure Kubernetes host automatically using environment variables available inside the pod
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

# Alternative: Manually provide host, CA cert, and a token reviewer JWT
# Note: The following commands extract necessary details from the vault-0 pod itself.
# Ensure the vault-0 pod's service account has permissions (e.g., system:auth-delegator ClusterRole)
# to review tokens if using token_reviewer_jwt.

# kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/config \
#     kubernetes_host="[https://kubernetes.default.svc:443](https://kubernetes.default.svc:443)" \
#     kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
#     token_reviewer_jwt=$(kubectl exec -it vault-0 -n vault -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
11. Creating a Vault PolicyDefine a policy that grants permissions to read/write secrets at a specific path within the KV engine.kubectl exec -it vault-0 -n vault -- vault policy write mysecret - << EOF
path "kv-v2/data/vault-demo/mysecret" {
  capabilities = ["create", "update", "read"]
}
EOF
12. Creating a Kubernetes Service AccountCreate a Kubernetes Service Account for your application. This service account will be linked to the Vault policy.# Create the Service Account in the namespace where your application will run (e.g., default)
kubectl create sa vault-demo-sa --namespace default
13. Creating a Vault Kubernetes Auth RoleCreate a role in Vault that links the Kubernetes Service Account (vault-demo-sa in the default namespace) to the Vault policy (mysecret) created earlier. Applications using this service account will be granted the permissions defined in the mysecret policy.kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/vault-demo \
  bound_service_account_names=vault-demo-sa \
  bound_service_account_namespaces=default \
  policies=mysecret \
  ttl=1h
bound_service_account_names: The name of the Kubernetes Service Account.bound_service_account_namespaces: The namespace of the Kubernetes Service Account.policies: The Vault policy/policies to assign to authenticated entities.ttl: The duration for which the Vault token issued upon successful login is valid.14. Storing Secrets in VaultCreate a JSON file with the secrets you want to store:cat > platform-env.json << EOF
{
    "EXTRACT_API_ENDPOINT": "http://extraction-api:8000",
    "KEYCLOAK_API_URL": "[http://keycloak-svc.keycloak.svc.cluster.local:80](http://keycloak-svc.keycloak.svc.cluster.local:80)",
    "KEYCLOAK_USER": "admin",
    "KEYCLOAK_PASSWORD": "ikxuW^uG6d:XU4S",
    "VECTORDB_USERNAME": "username",
    "VECTORDB_PASSWORD": "password",
    "VECTORDB_PORT": "19530"
}
EOF
Copy the file to the vault-0 pod and use the vault kv put command to store the secrets at the path defined in your policy:kubectl cp platform-env.json vault/vault-0:/tmp/platform-env.json -n vault
kubectl exec -it vault-0 -n vault -- sh -c 'vault kv put kv-v2/vault-demo/mysecret @/tmp/platform-env.json'
15. Verifying Stored SecretsYou can verify that the secrets were stored correctly:kubectl exec -it vault-0 -n vault -- vault kv get kv-v2/vault-demo/mysecret
16. Example: Fetching Secrets from a PodHere's an example of how a pod running with the vault-demo-sa Service Account can fetch secrets from Vault. These commands would typically run inside the application container:# 1. Define Vault address (use the internal service name)
VAULT_ADDR="[http://vault.vault.svc.cluster.local:8200](http://vault.vault.svc.cluster.local:8200)" # Or [http://vault-internal.vault:8200](http://vault-internal.vault:8200) depending on service name

# 2. Get the Kubernetes Service Account token mounted in the pod
SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# 3. Log in to Vault using the Kubernetes auth method and the SA token
#    Requires 'jq' to parse the JSON response. Install if necessary.
VAULT_RESPONSE=$(curl --request POST \
     --data '{"jwt": "'"$SA_TOKEN"'", "role": "vault-demo"}' \
     $VAULT_ADDR/v1/auth/kubernetes/login)

# 4. Extract the client token from the login response
VAULT_TOKEN=$(echo $VAULT_RESPONSE | jq -r '.auth.client_token')

# 5. Fetch the secret using the obtained Vault token
SECRET_RESPONSE=$(curl --header "X-Vault-Token: $VAULT_TOKEN" \
     $VAULT_ADDR/v1/kv-v2/data/vault-demo/mysecret)

# 6. Extract the actual secret data (requires jq)
SECRET_DATA=$(echo $SECRET_RESPONSE | jq -r '.data.data')

# 7. Use the secrets (example: print KEYCLOAK_USER)
echo $SECRET_DATA | jq -r '.KEYCLOAK_USER'
This concludes the basic setup and usage of
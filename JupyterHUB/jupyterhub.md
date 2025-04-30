# Deploying JupyterHub on Kubernetes using Helm

This guide outlines the steps to deploy JupyterHub on a Kubernetes cluster using Helm.

## 1. Add the JupyterHub Helm Repository

First, add the official JupyterHub Helm chart repository and update it to ensure you have the latest version of the chart.

```bash
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
```

## 2. Retrieve Default Values for Customization

To customize the deployment, extract the default values file of the JupyterHub chart.

```bash
helm show values jupyterhub/jupyterhub > values.yaml
```

We can now edit the `values.yaml` file to configure JupyterHub according to our requirements.

Common configurations include setting up authentication, resource limits, and enabling persistence for user data.

## 3. Deploy JupyterHub Using Helm

Deploy the JupyterHub Helm chart using the customized `values.yaml` file. The following command will install JupyterHub in a new namespace called `jhub`:

```bash
helm upgrade --cleanup-on-fail --install my-jupyter jupyterhub/jupyterhub --namespace jhub --create-namespace --values values.yaml
```

Options explained:
- `--cleanup-on-fail`: Ensures any failed installation attempts are cleaned up.
- `--install`: Installs the release if it is not already present.
- `--namespace jhub`: Specifies the namespace for the deployment.
- `--create-namespace`: Creates the namespace if it doesn't already exist.
- `--values values.yaml`: Uses the customized values file for configuration.

## 4. Handling Kubernetes Version Compatibility Errors

If we encounter the following error:
```
Error : K8s Version Compatibility error
```

### Step 4.1: Download and Extract the Helm Chart

Pull the JupyterHub Helm chart and untar it to access its contents:

```bash
helm pull jupyterhub/jupyterhub --untar
```

### Step 4.2: Modify the Chart.yaml File

Locate the Chart.yaml file in the extracted directory (`./jupyterhub/Chart.yaml`). Open the file in a text editor and adjust the kubeVersion field to match our Kubernetes version:

```yaml
#Example:
kubeVersion: ">=1.27.0-0"
```

This ensures the Helm chart is compatible with Kubernetes versions 1.27.0 and above.

## 5. Reinstall JupyterHub with the Modified Chart

After updating the kubeVersion field, use the local chart directory to install JupyterHub:

```bash
helm install my-jupyter ./jupyterhub --namespace jhub --create-namespace --values values.yaml
```

Note: Ensure the modified Chart.yaml is saved before running this command.

## 6. Verify the Deployment

Once the installation is complete, verify the JupyterHub deployment:

Check Pods:
```bash
kubectl get pods -n jhub
```

Ensure all pods are in the Running state.

Check Services:
```bash
kubectl get svc -n jhub
```

## Accessing JupyterHub: Two Methods

After deploying JupyterHub, we can access the interface using one of the following approaches:

### 1. Access via Istio Virtual Service

This method involves creating an Istio Virtual Service (VS) to expose JupyterHub externally through an Istio Gateway.

#### Steps to Create the Virtual Service

Apply the following YAML configuration to create a Virtual Service:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: jhub-vs
  namespace: jhub
spec:
  gateways:
  - kubeflow/kubeflow-gateway  # Update with your specific gateway if needed
  hosts:
  - change-to-platform-dns     # Replace with your external hostname or IP address
  http:
  - match:
    - uri:
        prefix: /hub             # Adjust the URI prefix if necessary
    rewrite:
      uri: /hub                  # Optionally rewrite the URI to root
    route:
    - destination:
        host: proxy-public.jhub.svc.cluster.local  # The JupyterHub service within your cluster
        port:
          number: 80             # Update the port if your service uses a different one
```

Apply it using kubectl:

```bash
kubectl apply -f jhub-virtualservice.yaml
```

#### Access JupyterHub

Once applied, you can access JupyterHub using the URL:

```
http://<platform-dns>/hub
```

Replace `<platform-dns>` with the hostname or external IP configured in the Virtual Service (e.g., labeeb-upgrade.katonic.ai).

### 2. Access via Port Forwarding

This method sets up port forwarding to temporarily expose the JupyterHub service on our local machine or VM.

#### Steps for Port Forwarding

Run the following command to forward traffic from our local machine to the JupyterHub service in the cluster:

```bash
kubectl port-forward svc/proxy-public -n jhub --address 0.0.0.0 8080:80
```

- `--address 0.0.0.0`: Makes the service accessible from all network interfaces on the VM.
- `8080:80`: Maps port 8080 on the local machine to port 80 of the service.

Access JupyterHub using:
```
http://<vm-ip>:8080
```

Replace `<vm-ip>` with the external IP of the VM where the port forwarding command is running.

## Accessing JupyterHub: Authentication and Backend Workflow

### Login Process

When accessing JupyterHub, you will see the login screen.

- Username: Enter your desired username (e.g., santosh)
- Password: Enter any password. Since the deployment uses a dummy authenticator by default, authentication does not enforce real credentials.
- Click Sign in to proceed.

### Server Setup

After signing in, JupyterHub will display a message indicating that your server is being set up in the backend.

### JupyterHub Interface

Once the server setup is complete, the JupyterHub interface will be accessible, allowing users to create and manage notebooks.

### Backend PVC Creation

In the background, a PersistentVolumeClaim (PVC) is automatically created for the user. This PVC is used to store the user's notebook data persistently.

The PVC details are as follows:
- Namespace: jhub
- Name: claim-<username> (e.g., claim-kasturi for the user kasturi).
- Size: The storage size of the PVC is determined by the configuration specified in the values.yaml file.

Ensure the values.yaml file is correctly configured to allocate sufficient storage for each user.
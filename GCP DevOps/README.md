# 🚀 GCP DevOps CI/CD Pipeline

This repository demonstrates a complete **CI/CD pipeline on Google Cloud** for a Python Flask application. It automates the build, testing (optional, not shown in this basic example), and deployment process using:

* **Cloud Build**: For orchestrating the CI/CD steps.
* **Docker**: For containerizing the Flask application.
* **Artifact Registry**: For storing Docker container images securely.
* **Google Kubernetes Engine (GKE)**: For deploying and managing the containerized application.
* **Kubernetes Manifests**: For defining the desired state of the application in GKE (Deployment and Service).

---

## 📁 Project Structure

```bash
.
├── Dockerfile                 # Defines the container image for the Flask app
├── requirements.txt           # Lists Python dependencies for the app
├── app.py                    # Example Flask application code
├── cloudbuild.yaml            # Configuration file for the Cloud Build pipeline
└── gke-deploy.yml             # Kubernetes manifests (Deployment & Service)
```

---

## 🔧 Technologies Used

* Python 3.8+ & Flask
* Docker
* Google Cloud Build
* Google Artifact Registry
* Google Kubernetes Engine (GKE)
* Kubernetes (Deployment, Service objects)


---
## ☸️ Create GKE cluster
![Google Kubernetes Engine](images/gkecluster.png)


## 🐳 Dockerfile

This `Dockerfile` builds a lightweight container image based on `python:3.8-slim-buster`. It installs dependencies and sets the command to run the Flask development server.

```dockerfile
# Use an official Python runtime as a parent image
FROM python:3.8-slim-buster

# Set the working directory in the container
WORKDIR /python-docker

# Copy the requirements file into the container at /python-docker
COPY requirements.txt requirements.txt

# Install any needed packages specified in requirements.txt
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /python-docker
COPY . .

# Make port 5000 available to the world outside this container
# (Note: GKE Service will handle external exposure)
# EXPOSE 5000 # Optional: Good practice for documentation

# Define environment variable (can be overridden)
ENV PORT 5000

# Run app.py when the container launches using Flask's built-in server
# Host 0.0.0.0 makes it accessible from outside the container within the K8s network
CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0", "--port=5000"]
```

---

## ☸️ Kubernetes Configuration (`gke-deploy.yml`)

This file contains the Kubernetes definitions for deploying the application.

### Deployment

Defines a Deployment object named `gcp-devops-gke` which ensures that one replica (instance) of the application pod is running. It uses a placeholder `IMAGE_TO_REPLACE` which will be dynamically updated by Cloud Build.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gcp-devops-gke # Name of the Deployment
spec:
  replicas: 1 # Number of desired pods
  selector:
    matchLabels:
      app: gcp # Pods with this label are managed by this Deployment
  template:
    metadata:
      labels:
        app: gcp # Label applied to the pods
    spec:
      containers:
      - name: gcp-devops-gke # Name of the container within the pod
        image: IMAGE_TO_REPLACE # Placeholder - Cloud Build will replace this
        ports:
        - containerPort: 5000 # Port the application listens on inside the container
        env:
          - name: PORT # Environment variable for the application
            value: "5000"
```

### Service

Defines a Service object named `gcp-devops-gke-service` of type `LoadBalancer`. This exposes the Deployment externally by creating a Google Cloud Load Balancer, directing traffic from port 80 to the container's `targetPort` 5000.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: gcp-devops-gke-service # Name of the Service
  namespace: gcp-devops-prod # Deploy the service in this specific namespace
  labels:
    # Label indicating this service is managed by Cloud Build deployment steps
    app.kubernetes.io/managed-by: gcp-cloud-build-deploy
spec:
  ports:
    - protocol: TCP
      port: 80 # Port the Load Balancer listens on
      targetPort: 5000 # Port on the pods to forward traffic to
  selector:
    app: gcp # Selects pods with this label to send traffic to
  type: LoadBalancer # Exposes the service externally using a cloud provider's load balancer
```

---

## ⚙️ Cloud Build Pipeline (`cloudbuild.yaml`)

This file defines the steps executed by Google Cloud Build.

```yaml
steps:
# 1. Build the Docker image
# Uses the Docker builder to build the image using the Dockerfile in the current directory.
# Tags the image with the Artifact Registry path, incorporating location, project ID, repo name, image name, and the unique Build ID.
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_IMAGE}:${BUILD_ID}', '.']

# 2. Push the Docker image to Artifact Registry
# Pushes the tagged image built in the previous step to the specified Artifact Registry repository.
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_IMAGE}:${BUILD_ID}']

# 3. Update Kubernetes Manifest (Deployment)
# Uses the gcloud SDK builder to run a bash command.
# `sed` is used to find and replace the placeholder 'IMAGE_TO_REPLACE' in gke-deploy.yml
# with the actual image path pushed in the previous step. The '-i' flag modifies the file in place.
- name: 'gcr.io/[google.com/cloudsdktool/cloud-sdk](https://google.com/cloudsdktool/cloud-sdk)'
  entrypoint: 'bash'
  args:
    - '-c'
    - |
      sed -i "s|IMAGE_TO_REPLACE|${_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_IMAGE}:${BUILD_ID}|g" gke-deploy.yml

# 4. Deploy to GKE using gke-deploy
# Uses the gke-deploy builder, a specialized tool for safe GKE deployments.
# The 'run' command applies the manifests in gke-deploy.yml to the specified GKE cluster and namespace.
- name: "gcr.io/cloud-builders/gke-deploy"
  args:
    - run
    - --filename=gke-deploy.yml
    - --location=us-central1-c # Zone/Region of the GKE cluster
    - --cluster=gcp-devops      # Name of the GKE cluster
    - --namespace=gcp-devops-prod # Target namespace within the cluster

# Substitutions: Default values for variables used in the steps.
# These can be overridden when triggering the build manually or via triggers.
substitutions:
  _LOCATION: 'us' # Default Artifact Registry location (multi-region)
  _REPOSITORY: 'gcpdevops' # Default Artifact Registry repository name
  _IMAGE: 'gcpdevopssantosh' # Default image name

# Options for the build execution.
options:
  dynamicSubstitutions: true # Allows use of dynamic variables like BUILD_ID, PROJECT_ID
  logging: GCS_ONLY # Store build logs only in Google Cloud Storage

logsBucket: 'gs://gcpdevops-s' # Specific GCS bucket for storing logs

# Service Account: Specifies the identity Cloud Build uses to execute the steps.
# This account needs appropriate IAM permissions. Use this service account also for GKE cluster
serviceAccount: 'projects/ds-team-384807/serviceAccounts/gcp-devops@ds-team-384807.iam.gserviceaccount.com'
```

---

## 🔐 IAM Requirements

The specified Cloud Build `serviceAccount` (`gcp-devops@backend-56707.iam.gserviceaccount.com` in this example) requires the following IAM roles on your Google Cloud project (`backend-56707`):

* **Artifact Registry Writer** (`roles/artifactregistry.writer`): To push Docker images to Artifact Registry.
* **Kubernetes Engine Developer** (`roles/container.developer`): To deploy applications and manage resources within the GKE cluster.
* **Cloud Build Editor** (`roles/cloudbuild.builds.editor`): Generally needed for Cloud Build operations (may be implicitly granted depending on setup).
* **Service Account User** (`roles/iam.serviceAccountUser`): Required for the Cloud Build service account to act *as itself* when interacting with other GCP services like GKE and Artifact Registry.
* **(Optional) Viewer** (`roles/viewer`): Useful for debugging and inspecting resources.

---

## 🚀 How It Works

1.  **Trigger**: A push to the configured branch (e.g., `main`) in your source repository (GitHub, Cloud Source Repositories) triggers the Cloud Build pipeline.
2.  **Build**: Cloud Build executes the steps defined in `cloudbuild.yaml`.
3.  **Image Build & Push**: A Docker image is built using the `Dockerfile` and tagged with a unique build ID. This image is then pushed to your Artifact Registry repository.
4.  **Manifest Update**: The `gke-deploy.yml` file is dynamically updated using `sed` to replace the `IMAGE_TO_REPLACE` placeholder with the specific Artifact Registry path of the newly built image.
5.  **Deploy**: The `gke-deploy` tool applies the updated `gke-deploy.yml` manifest to your GKE cluster (`gcp-devops`), deploying or updating the application within the `gcp-devops-prod` namespace.
6.  **Expose**: The Kubernetes Service of type `LoadBalancer` provisions a Google Cloud Load Balancer, making your application accessible via an external IP address.

Some screenshots of project
 CodeBuild pipeline
 ![Pipeline](images/codebuild1.png)

 Artifact Registry
 ![Pipeline](images/artifactregistry.png)

 Logs Stored in GCS
 ![gcs](images/gcpgcsbucket.png)

---

## 🌐 Accessing the Application

Once the Cloud Build pipeline completes successfully:

1.  **Connect to your GKE cluster** (if you haven't already):

2.  **Get the Service details** to find the external IP:
    ```bash
    kubectl get svc gcp-devops-gke-service -n gcp-devops-prod
    ```
    Look for the value in the `EXTERNAL-IP` column. It might take a minute or two to become available after deployment.
3.  **Open the application** in your web browser:
    `http://<EXTERNAL-IP>` (Uses port 80 by default as defined in the Service)

    ![Kubernetes Service](images/k8s.png))

    Access the application
    ![access](images/accessapp.png))


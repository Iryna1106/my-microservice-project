# Lesson 7 — Kubernetes (EKS) + ECR + Helm

## 📁 Project structure

```
lesson-7/
├── main.tf                 # connects the four modules together
├── backend.tf              # S3 + DynamoDB remote-state backend
├── providers.tf            # AWS provider (region)
├── versions.tf             # required Terraform & provider versions
├── outputs.tf              # combined outputs (incl. the kubeconfig command)
├── README.md               # this file
├── modules/
│   ├── s3-backend/         # S3 bucket + DynamoDB lock table (Terraform state)
│   ├── vpc/                # VPC, subnets, gateways, routing (+ LB subnet tags)
│   ├── ecr/                # ECR Docker image repository
│   └── eks/                # the Kubernetes cluster + worker node group
└── charts/
    └── django-app/         # Helm chart for the Django app
        ├── Chart.yaml
        ├── values.yaml     # all settings (image, service, autoscaler, config)
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── configmap.yaml   # env vars carried over from theme 4
            └── hpa.yaml
```

## ✅ Prerequisites

You need these tools installed and AWS credentials configured (`aws configure`):

| Tool      | Check command       |
| --------- | ------------------- |
| Terraform | `terraform version` |
| AWS CLI   | `aws --version`     |
| Docker    | `docker --version`  |
| kubectl   | `kubectl version`   |
| Helm      | `helm version`      |

Install the two missing tools (Ubuntu/WSL2):

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

### 1. Create the infrastructure with Terraform

```bash
cd lesson-7

mv backend.tf backend.tf.bak

terraform init                  # 2) init with local state
terraform apply                 # 3) creates VPC, ECR, EKS, S3 bucket + DynamoDB
                                #    (EKS takes ~10–15 minutes — be patient)

# 4) Re-enable the S3 backend and move the state into the new bucket.
mv backend.tf.bak backend.tf
terraform init -migrate-state   # answer "yes" to copy state into S3
```

> 💡 Note: `terraform init -backend=false` lets you `validate`/`plan` without a
> backend, but `terraform apply` refuses to run without an initialized backend —
> that's why we set `backend.tf` aside for the first apply instead.

After this, see all the important values:

```bash
terraform output
```

### 2. Point kubectl at the new cluster

`terraform output` prints a ready-to-run command. It looks like:

```bash
aws eks update-kubeconfig --region us-west-2 --name lesson-7-eks
```

Check it works (you should see the 2 worker nodes):

```bash
kubectl get nodes
```

### 3. Build the Docker image and push it to ECR

Get the repository URL:

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "$ECR_URL"
```

Log in, build, tag, and push (run these from the **project root**, where the
`Dockerfile` lives — i.e. `cd ..` first):

```bash
cd ..   # back to the project root (where the Dockerfile is)

# Log Docker in to ECR
aws ecr get-login-password --region us-west-2 \
  | docker login --username AWS --password-stdin "$ECR_URL"

# Build, tag, and push the image
docker build -t django-app .
docker tag django-app:latest "$ECR_URL:latest"
docker push "$ECR_URL:latest"
```

### 4. Install metrics-server (required for the HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait until it's ready
kubectl -n kube-system rollout status deployment/metrics-server
```

### 5. Deploy the app with Helm

Edit `lesson-7/charts/django-app/values.yaml` and set `image.repository` to your
ECR URL (the `$ECR_URL` value from step 3). Then install:

```bash
helm install django-app ./lesson-7/charts/django-app
```

Or skip editing the file and pass the URL on the command line:

```bash
helm install django-app ./lesson-7/charts/django-app \
  --set image.repository="$ECR_URL" --set image.tag=latest
```

### 6. Verify it works

```bash
kubectl get pods            # should show 2 Running pods
kubectl get svc django-app  # copy the EXTERNAL-IP (the load balancer address)
kubectl get hpa django-app  # TARGETS should show a number like "1%/70%"
```

Open the `EXTERNAL-IP` in a browser (it can take 1–3 minutes for AWS to create
the load balancer). Visiting `/admin/` shows the Django login page.

**See the autoscaler in action (optional):** generate CPU load and watch the pod
count climb toward 6:

```bash
kubectl get hpa django-app --watch
```

The `LoadBalancer` Service makes Kubernetes create an AWS load balancer that
**Terraform does not know about**. If you run `terraform destroy` first, that
orphaned load balancer keeps network interfaces in the subnets and the **VPC
destroy will fail / hang**.

Always remove the Helm release first:

```bash
# 1) Delete the app (this removes the Service → AWS deletes the load balancer)
helm uninstall django-app

# 2) Wait ~1–2 minutes for the load balancer + its network interfaces to clear

# 3) Now destroy the infrastructure
cd lesson-7
terraform destroy
```

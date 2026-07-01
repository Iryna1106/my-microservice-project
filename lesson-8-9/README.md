# Lessons 8–9 — CI/CD with Jenkins + Terraform + Helm + ECR + Argo CD

A complete **GitOps CI/CD pipeline** built on top of lesson 7's EKS cluster.
No manual `kubectl apply` or `docker push` — you press **Build** in Jenkins once,
and the new version of the app appears in the cluster on its own.

- **CI (Jenkins)** — builds the Django Docker image with **Kaniko**, pushes it to
  **Amazon ECR**, rewrites the image tag in the Helm chart, and pushes that change
  to Git.
- **CD (Argo CD)** — watches Git and automatically syncs the updated Helm chart
  into the cluster.

Everything (the cluster, Jenkins, and Argo CD) is installed by **Terraform** using
**Helm** — one tool, one `terraform apply`.

---

## 🔄 The CI/CD flow (the "scheme")

```
   You (developer)
       │  git push  (change the app's Python code)  ──▶  GitHub: branch lesson-8-9
       │
       ▼  click "Build Now"
 ┌──────────────────────── JENKINS  (runs inside EKS) ─ CI ────────────────────────┐
 │                                                                                 │
 │   Jenkins launches a throw-away AGENT POD with two tool containers:             │
 │                                                                                 │
 │   ┌──────────────┐   1) build image from Dockerfile                            │
 │   │   kaniko     │   2) push image ─────────────────────────┐                  │
 │   └──────────────┘                                          ▼                  │
 │                                                     ┌──────────────────┐        │
 │   ┌──────────────┐   3) sed image.tag in            │   Amazon ECR     │        │
 │   │   git        │      values.yaml                 │  (image registry)│        │
 │   │              │   4) git commit + push ──┐       └──────────────────┘        │
 │   └──────────────┘                          │                                   │
 └─────────────────────────────────────────────┼───────────────────────────────────┘
                                               ▼
                                   GitHub repo, branch lesson-8-9
                                   (values.yaml now has the new tag)
                                               │
                                               │  Argo CD is watching this branch
                                               ▼
 ┌──────────────────────── ARGO CD  (runs inside EKS) ─ CD ────────────────────────┐
 │                                                                                 │
 │   sees the new tag  →  re-renders the Helm chart  →  applies it to the cluster  │
 │                                                                                 │
 │            ┌───────────────────────────────────────────────┐                   │
 │            │  django-app Deployment (NEW image) + Service   │  ──▶ users        │
 │            └───────────────────────────────────────────────┘                   │
 └─────────────────────────────────────────────────────────────────────────────────┘
```

**One sentence:** *Jenkins builds & publishes the image and writes the new tag to
Git; Argo CD reads Git and makes the cluster match it.*

---

## 📁 Project structure

```
lesson-8-9/
├── main.tf                  # wires all modules together (+ jenkins, argo_cd)
├── backend.tf               # S3 + DynamoDB remote-state backend
├── providers.tf             # aws + kubernetes + helm providers (point at EKS)
├── versions.tf              # required Terraform & provider versions
├── variables.tf             # GitOps settings (repo URL, branch, chart path)
├── outputs.tf               # combined outputs (URLs, password commands)
├── README.md                # this file
│
├── modules/
│   ├── s3-backend/          # S3 bucket + DynamoDB lock table (TF state)
│   ├── vpc/                 # VPC, subnets, gateways, routing
│   ├── ecr/                 # ECR Docker image repository
│   ├── eks/                 # the cluster + node group
│   │   ├── eks.tf                # cluster, IAM (+ ECR *push* on nodes for Kaniko)
│   │   ├── aws_ebs_csi_driver.tf # OIDC provider + EBS CSI driver (Jenkins disk)
│   │   └── ...
│   ├── jenkins/             # ✅ Helm install of Jenkins
│   │   ├── jenkins.tf            # helm_release
│   │   ├── values.yaml          # Jenkins config (LB, persistence, plugins)
│   │   ├── variables.tf / providers.tf / outputs.tf
│   └── argo_cd/             # ✅ Helm install of Argo CD
│       ├── argo_cd.tf           # helm_release (Argo CD) + app-of-apps release
│       ├── values.yaml          # Argo CD config (LB, insecure UI)
│       ├── variables.tf / providers.tf / outputs.tf
│       └── charts/              # local "app-of-apps" Helm chart
│           ├── Chart.yaml
│           ├── values.yaml       # repo URL, branch, path, app name
│           └── templates/
│               ├── application.yaml   # the Argo CD Application (auto-sync)
│               └── repository.yaml    # repo credential (only for PRIVATE repos)
│
└── charts/
    └── django-app/          # the app's Helm chart (Argo CD deploys THIS)
        ├── Chart.yaml
        ├── values.yaml       # image.repository/tag, service, config…
        └── templates/        # deployment, service, configmap, hpa

Jenkinsfile                   # (repo ROOT) the CI pipeline
Dockerfile                    # (repo ROOT) how the image is built
```

---

## ✅ Prerequisites

Same tools as lesson 7, plus **Helm** is used *by Terraform* (you don't call it
directly). AWS credentials must be configured (`aws configure`).

| Tool      | Check command       |
| --------- | ------------------- |
| Terraform | `terraform version` |
| AWS CLI   | `aws --version`     |
| kubectl   | `kubectl version`   |
| Docker    | `docker --version`  |

> 💡 The defaults use region `us-west-2` and the author's repo, but **nothing is
> hard-coded** — see "⚙️ Make it your own" next to run it in your own account.

---

## ⚙️ Make it your own (run it in YOUR account & repo)

Every account/repo-specific value is a **variable** or **parameter**. Defaults
match the author's setup, so leaving them alone also works.

**Terraform** — set these in a `terraform.tfvars` file *or* as `TF_VAR_...`
environment variables. Your **AWS account ID is detected automatically**, so you
never type or expose it.

```bash
cd lesson-8-9
cp terraform.tfvars.example terraform.tfvars   # then edit only what you want to change
```

| Variable | What it is | Default |
| --- | --- | --- |
| `aws_region` | region to deploy into (needs ≥3 AZs) | `us-west-2` |
| `project_name` | name prefix for VPC / ECR / EKS / state | `lesson-8-9` |
| `gitops_repo_url` | your Git repo (HTTPS) | the author's repo |
| `gitops_branch` | branch Argo watches / Jenkins pushes to | `lesson-8-9` |
| `gitops_chart_path` | chart folder inside the repo | `lesson-8-9/charts/django-app` |

**`backend.tf`** — the ONE file that can't use variables (Terraform reads it
before variables exist). If you change account / region / `project_name`, edit the
four lines marked `← EDIT` in `backend.tf` so they match.

**Jenkinsfile** — its values are **build parameters** (`AWS_REGION`,
`ECR_REGISTRY`, `ECR_REPO`, `GITOPS_BRANCH`, `GIT_REPO_HOST_PATH`). The first
build uses the defaults; after that use **Build with Parameters** to change them
— no editing the file.

**The ECR image URL** is passed from Terraform into the Argo CD app automatically
(built from your account + region), so it is **not** hard-coded in the chart.

---

## Part 1 — Install the cluster + Jenkins + Argo CD with Terraform

### Why the two-step apply?

The `kubernetes` and `helm` providers need to *connect* to the cluster — but on
the very first run the cluster doesn't exist yet. You can't hang a picture on a
wall that hasn't been built. So we build the wall (the EKS cluster) **first**,
then install Jenkins & Argo CD onto it.

We also start with **local** state because the S3 state bucket is created by this
same project (the same bootstrap trick as lesson 7).

```bash
cd lesson-8-9

# 0) (Optional) set your own region/repo — see "Make it your own" above.
#    Skipping this uses the defaults, which also work.

# 1) Start with LOCAL state (the S3 bucket doesn't exist yet).
mv backend.tf backend.tf.bak
terraform init

# 2) Build the network + cluster FIRST (VPC, EKS, OIDC, EBS CSI driver).
#    This takes ~15 minutes — EKS is slow to create. Be patient.
#    ⚠️ BOTH targets are required: with only -target=module.eks, Terraform skips
#    the NAT gateway + route tables in module.vpc (nothing in module.eks refers to
#    them), so private-subnet nodes can't reach the internet/EC2 API and never
#    join the cluster (NodeCreationFailure).
terraform apply -target=module.vpc -target=module.eks

# 3) Build everything else: S3 backend, ECR, Jenkins, Argo CD.
#    Now that the cluster exists, the helm/kubernetes providers can connect.
terraform apply

# 4) Move the Terraform state into the S3 bucket we just created.
mv backend.tf.bak backend.tf
terraform init -migrate-state        # answer "yes"
```

When it finishes, see the useful values:

```bash
terraform output
```

Point `kubectl` at the cluster (the command is in the output):

```bash
aws eks update-kubeconfig --region us-west-2 --name lesson-8-9-eks
kubectl get nodes                    # should show 2 worker nodes
kubectl get pods -n jenkins          # Jenkins controller should be Running
kubectl get pods -n argocd           # Argo CD pods should be Running
```

---

## Part 2 — Configure Jenkins and run the pipeline

### 2.1 Open Jenkins & log in

```bash
# Public address of the Jenkins UI (may take 1-3 min for AWS to assign it):
kubectl -n jenkins get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo

# The auto-generated admin password (username is 'admin'):
kubectl -n jenkins get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode; echo
```

Open `http://<that-address>/` and log in as **admin**.

### 2.2 Add the GitHub credential (one time)

The pipeline pushes the tag change back to GitHub, so it needs a token.

1. Create a **GitHub Personal Access Token (PAT)** with the **`repo`** scope
   (GitHub → Settings → Developer settings → Personal access tokens).
2. In Jenkins: **Manage Jenkins → Credentials → System → Global → Add Credentials**
   - **Kind:** Username with password
   - **Username:** your GitHub username (e.g. `Iryna1106`)
   - **Password:** the PAT
   - **ID:** `github-pat`  ← must match the `Jenkinsfile`

### 2.3 Create the pipeline job

**New Item → Pipeline** → name it `django-ci` → **OK**, then:

- **Pipeline → Definition:** *Pipeline script from SCM*
- **SCM:** Git
- **Repository URL:** `https://github.com/<your-user>/<your-repo>.git`
- **Branch:** `*/lesson-8-9`
- **Script Path:** `Jenkinsfile`
- **Save**.

> The pipeline's ECR/region/repo values are **build parameters** with defaults
> (see the `parameters` block in the `Jenkinsfile`). The **first** build uses the
> defaults automatically; after that, use **Build with Parameters** to change any
> of them without editing the file.

### 2.4 Run it

Click **Build Now**. The pipeline will:

1. spin up an agent pod (`kaniko` + `git` containers),
2. **build** the image and **push** `…/lesson-8-9-ecr:<build-number>` (and `:latest`) to ECR,
3. rewrite `image.tag` in `lesson-8-9/charts/django-app/values.yaml`,
4. **commit & push** that change to the `lesson-8-9` branch.

Confirm the image landed in ECR:

```bash
aws ecr list-images --repository-name lesson-8-9-ecr --region us-west-2
```

> 💡 **No image build without app changes?** Kaniko still rebuilds every run and
> tags it with a fresh build number, so Argo CD always gets a new tag to deploy.

---

## Part 3 — Argo CD: watch it sync

### 3.1 Open Argo CD & log in

```bash
# Public address of the Argo CD UI:
kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo

# The admin password (username is 'admin'):
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo
```

Open `http://<that-address>/` and log in as **admin**.

### 3.2 What you should see

Terraform already created an Argo CD **Application** called `django-app` that
watches `lesson-8-9/charts/django-app` on the `lesson-8-9` branch, with
**automated sync** turned on (`prune` + `selfHeal`). So:

- Right after install, Argo CD deploys the app into the **`django`** namespace.
  > ⚠️ **Cold start.** Before you have run Jenkins even once, the chart points at
  > `…/lesson-8-9-ecr:latest`, but **nothing has been pushed to ECR yet**. So the
  > pods show `ImagePullBackOff` and Argo CD shows **Synced but Degraded** — this
  > is expected. Run the Jenkins pipeline once (Part 2); after it pushes an image,
  > Argo CD self-heals to **Healthy** on its own. (It makes a nice before/after demo.)
- After each Jenkins build (which changes the tag in Git), Argo CD notices within
  ~3 minutes and rolls out the new image — **Synced / Healthy**.

Check from the terminal too:

```bash
kubectl get applications -n argocd                 # SYNC=Synced, HEALTH=Healthy
kubectl get pods -n django                          # the running app pods
kubectl get svc  -n django django-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
```

Open the app's `EXTERNAL-IP`/hostname in a browser — `/admin/` shows the Django
login page.

> ⏱️ **Want an instant sync** instead of waiting for the poll? In the Argo CD UI
> click **Sync**, or run `argocd app sync django-app`.

---

## 🧪 End-to-end test (the whole point)

1. Change something visible in the Django app and `git push` to `lesson-8-9`.
2. In Jenkins, **Build Now** (or set up a webhook — see note below).
3. Watch Jenkins go green (image pushed, tag committed).
4. Watch Argo CD flip to **OutOfSync → Syncing → Synced** and the pods restart
   with the new image. You changed **nothing** by hand in the cluster. ✅

> **Loop safety:** the tag-update commit message ends with `[skip ci]`. If you
> later add an SCM webhook so pushes trigger builds automatically, configure it
> to ignore commits from Jenkins, or the pipeline would trigger itself forever.

---

## 🧹 Teardown (ORDER MATTERS — read this)

The `LoadBalancer` Services (django-app, Jenkins, Argo CD) make AWS create load
balancers that **Terraform doesn't track**. If you `terraform destroy` first,
those orphaned load balancers keep network interfaces in the subnets and the
**VPC destroy will hang/fail**. Remove the in-cluster things first:

```bash
# 1) Delete the app Argo CD manages, then Argo CD & Jenkins (removes their LBs).
kubectl delete application django-app -n argocd     # or: argocd app delete django-app
helm uninstall argocd  -n argocd
helm uninstall jenkins -n jenkins

# 2) Wait ~2 minutes for AWS to delete the load balancers + their ENIs.

# 3) Now destroy the infrastructure.
cd lesson-8-9
terraform destroy
```

> If `destroy` still hangs on the VPC, check the AWS Console → EC2 → Load
> Balancers for leftovers, delete them, then re-run `terraform destroy`.

---

## 🆘 Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| `terraform apply` errors *"cluster unreachable / no configuration"* | You skipped the `-target=module.eks` step. Build the cluster first (Part 1). |
| Jenkins pod stuck **Pending**, PVC **Pending** | EBS CSI driver not ready. It's installed by the `eks` module — check `kubectl get pods -n kube-system | grep ebs`. |
| Kaniko fails to **push** to ECR | Nodes need ECR push rights (added in `modules/eks/eks.tf` as `…RegistryPowerUser`). Confirm the ECR repo name/region match the `Jenkinsfile`. |
| Agent pod never becomes **Ready** | The `kaniko`/`git` containers must stay alive (`command: cat`, `tty: true`) — already set in the `Jenkinsfile`. |
| `git push` rejected in the pipeline | The `github-pat` credential is missing/expired, or the PAT lacks `repo` scope. |
| Argo CD app **OutOfSync** and won't move | Make sure the chart really exists on the `lesson-8-9` branch at `lesson-8-9/charts/django-app`, and that Jenkins pushed there. |
| HPA shows `<unknown>/70%` | Autoscaling is **off** by default here. To use it, install metrics-server (`kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`) and set `autoscaling.enabled: true` in `values.yaml`. |

---

## 🗺️ Which grading item lives where

| Grading item | Where in this project |
| --- | --- |
| Jenkins + Terraform + Helm (20) | `modules/jenkins/` + `main.tf` `module "jenkins"` |
| Jenkins pipeline: build, push, update Git (30) | `Jenkinsfile` (repo root) |
| Argo CD + Terraform + Helm (20) | `modules/argo_cd/` + `main.tf` `module "argo_cd"` |
| Argo Application w/ full Helm sync (20) | `modules/argo_cd/charts/templates/application.yaml` |
| README with commands & CI/CD scheme (10) | this file |
```

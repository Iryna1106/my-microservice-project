// =============================================================================
//  Jenkinsfile — the CI pipeline (lessons 8-9).
//
//  What it does, top to bottom:
//    1. Runs on a throwaway Kubernetes "agent" pod with two tool containers:
//         • kaniko — builds a Docker image WITHOUT a Docker daemon and pushes
//                    it to Amazon ECR.
//         • git    — edits the Helm chart and pushes the change back to GitHub.
//    2. Builds the Django image from the repo's Dockerfile.
//    3. Pushes it to ECR, tagged with the Jenkins build number (and 'latest').
//    4. Updates image.tag in the Helm chart's values.yaml.
//    5. Commits & pushes that one-line change to the GitOps branch.
//
//  Argo CD (installed separately) then notices the Git change and rolls the new
//  image out to the cluster — no manual kubectl needed. That is the CD half.
//
//  ── Before the FIRST run, in the Jenkins UI create one credential ──────────
//    Manage Jenkins → Credentials → (global) → Add Credentials
//      Kind:     Username with password
//      Username: your GitHub username        (e.g. Iryna1106)
//      Password: a GitHub Personal Access Token with 'repo' scope
//      ID:       github-pat                  (must match GIT_CREDENTIALS_ID below)
// =============================================================================

pipeline {

  // ---- Where the build runs: a Kubernetes pod defined inline ----
  agent {
    kubernetes {
      // The two tool containers. Each has 'command: cat' + 'tty: true' so the
      // container starts and STAYS ALIVE waiting for us to run steps in it.
      // (Without this, kaniko would run once and the pod would exit before the
      //  pipeline could use it — the classic "agent never becomes Ready" trap.)
      yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command: ['/busybox/cat']
      tty: true
      env:
        # Lets Kaniko use the worker node's IAM role (via IMDS) to log in to ECR.
        # The region is exported from the AWS_REGION parameter in the build step.
        - name: AWS_SDK_LOAD_CONFIG
          value: "true"
      resources:
        requests:
          cpu: "500m"
          memory: "1024Mi"
        limits:
          cpu: "1500m"
          memory: "2560Mi"
    - name: git
      image: alpine/git:latest
      command: ['cat']
      tty: true
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
'''
    }
  }

  options {
    // NOTE: timestamps() is intentionally NOT used — it needs the Timestamper
    // plugin, which this chart doesn't install. (Add 'timestamper' to the
    // Jenkins additionalPlugins if you want per-line timestamps.)
    disableConcurrentBuilds()    // one build at a time (avoids Git push races)
  }

  // ---- Configurable values, exposed as build PARAMETERS (Jenkins "env vars") ----
  // The FIRST build uses these DEFAULTS automatically. After that, click
  // "Build with Parameters" to override any of them without editing this file.
  parameters {
    string(name: 'AWS_REGION', defaultValue: 'us-west-2',
           description: 'AWS region of your ECR registry.')
    string(name: 'ECR_REGISTRY', defaultValue: '139214069645.dkr.ecr.us-west-2.amazonaws.com',
           description: 'ECR registry host: <account-id>.dkr.ecr.<region>.amazonaws.com')
    string(name: 'ECR_REPO', defaultValue: 'lesson-8-9-ecr',
           description: 'ECR repository name (matches Terraform project_name + "-ecr").')
    string(name: 'GITOPS_BRANCH', defaultValue: 'lesson-8-9',
           description: 'Branch to push the image-tag update to (must match Argo CD targetRevision).')
    string(name: 'CHART_VALUES', defaultValue: 'lesson-8-9/charts/django-app/values.yaml',
           description: "Path to the Helm values.yaml whose image.tag is rewritten.")
    string(name: 'GIT_REPO_HOST_PATH', defaultValue: 'github.com/Iryna1106/my-microservice-project.git',
           description: 'Git repo to push to (host/path, NO https:// prefix).')
  }

  environment {
    // Everything below is pulled from the parameters above — nothing hard-coded.
    AWS_REGION   = "${params.AWS_REGION}"
    ECR_REGISTRY = "${params.ECR_REGISTRY}"
    ECR_REPO     = "${params.ECR_REPO}"
    IMAGE        = "${params.ECR_REGISTRY}/${params.ECR_REPO}"
    IMAGE_TAG    = "${env.BUILD_NUMBER}"          // a unique, increasing tag

    // --- GitOps target (must match Argo CD's targetRevision) ---
    GITOPS_BRANCH      = "${params.GITOPS_BRANCH}"
    CHART_VALUES       = "${params.CHART_VALUES}"
    GIT_REPO_HOST_PATH = "${params.GIT_REPO_HOST_PATH}"
    GIT_CREDENTIALS_ID = 'github-pat'
  }

  stages {

    // ---- 1. Get the source code ----
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    // ---- 2. Build the image and push it to ECR (with Kaniko) ----
    stage('Build & Push image') {
      steps {
        // shell: '/busybox/sh' — the kaniko:debug image ships busybox, whose
        // shell lives at /busybox/sh (there is no /bin/sh), so we tell Jenkins
        // to use it for the 'sh' step below.
        container(name: 'kaniko', shell: '/busybox/sh') {
          sh '''#!/busybox/sh
            set -e
            # Region for the AWS credential lookup (from the AWS_REGION parameter).
            export AWS_DEFAULT_REGION="${AWS_REGION}"
            echo "Building ${IMAGE}:${IMAGE_TAG} and pushing to ECR..."
            # Kaniko auto-detects the ECR registry and logs in using the worker
            # node's IAM role (which has ECR push rights) — no docker login needed.
            /kaniko/executor \
              --context="dir://${WORKSPACE}" \
              --dockerfile="Dockerfile" \
              --destination="${IMAGE}:${IMAGE_TAG}" \
              --destination="${IMAGE}:latest" \
              --verbosity=info
          '''
        }
      }
    }

    // ---- 3. Update the Helm chart's image tag and push it to Git ----
    stage('Update Helm chart tag') {
      steps {
        container('git') {
          // Injects the GitHub token as $GIT_USER / $GIT_TOKEN. Jenkins masks
          // these values in the console output automatically.
          withCredentials([usernamePassword(
              credentialsId: env.GIT_CREDENTIALS_ID,
              usernameVariable: 'GIT_USER',
              passwordVariable: 'GIT_TOKEN')]) {
            sh '''#!/bin/sh
              set -e

              # Jenkins checked the repo out as a different user; tell git it is
              # safe to operate on this directory.
              git config --global --add safe.directory "${WORKSPACE}"
              git config user.email "jenkins@ci.local"
              git config user.name  "Jenkins CI"

              echo "Setting image.tag to ${IMAGE_TAG} in ${CHART_VALUES}"
              # Replace the 'tag:' line under the image: block with the new tag.
              sed -i "s|^\\([[:space:]]*\\)tag:.*|\\1tag: \\"${IMAGE_TAG}\\"|" "${CHART_VALUES}"

              echo "----- resulting image block -----"
              grep -A2 "^image:" "${CHART_VALUES}" || true
              echo "---------------------------------"

              git add "${CHART_VALUES}"

              # If nothing changed (e.g. re-run with same tag), don't fail.
              if git diff --cached --quiet; then
                echo "No change to commit — values.yaml already up to date."
                exit 0
              fi

              # '[skip ci]' documents that this commit is machine-made; if you
              # later add an SCM webhook, configure it to ignore such commits so
              # the pipeline doesn't trigger itself in a loop.
              git commit -m "ci: update django-app image tag to ${IMAGE_TAG} [skip ci]"

              # Push the new commit onto the GitOps branch. HEAD is detached
              # (SCM checkout), so we push HEAD to the branch ref explicitly.
              git push "https://${GIT_USER}:${GIT_TOKEN}@${GIT_REPO_HOST_PATH}" \
                "HEAD:${GITOPS_BRANCH}"

              echo "Pushed image tag ${IMAGE_TAG} to ${GITOPS_BRANCH}."
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo "✅ Done. Image ${IMAGE}:${IMAGE_TAG} pushed; chart tag updated on ${GITOPS_BRANCH}."
      echo "Argo CD will now sync the new image into the cluster automatically."
    }
    failure {
      echo "❌ Pipeline failed — check the stage logs above."
    }
  }
}

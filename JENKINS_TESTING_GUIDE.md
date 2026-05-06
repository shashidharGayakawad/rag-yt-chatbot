# Jenkins CI/CD Testing Guide

This guide covers how to test the RAG chatbot CI/CD pipeline using Jenkins.

## Quick Start: Local Jenkins Setup

### Prerequisites

- Docker installed
- docker-compose installed
- Git installed
- kubectl installed (optional, for Kubernetes deployment)

### Installation (1 minute)

**Step 1: Start Jenkins**

```bash
cd /path/to/CICD
docker-compose -f docker-compose.jenkins.yml up -d
```

**Step 2: Get Initial Admin Password**

```bash
docker-compose -f docker-compose.jenkins.yml logs jenkins | grep -A 5 "Initial Admin Password"
```

**Step 3: Access Jenkins**

- Open http://localhost:8080
- Enter the initial admin password
- Complete setup wizard

---

## Setting Up Jenkins Credentials

### 1. Docker Hub Credentials

1. Go to **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Fill in:
   - Kind: **Username with password**
   - Username: Your Docker Hub username
   - Password: Your Docker Hub password or PAT
   - ID: `docker-hub-credentials`
4. Click **Create**

### 2. Kubeconfig (Optional)

1. Go to **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Fill in:
   - Kind: **Secret file**
   - File: Upload your `~/.kube/config` file
   - ID: `kubeconfig-file`
4. Click **Create**

---

## Creating and Running Test Pipeline

### Create Test Job

1. Click **New Item** on Jenkins Dashboard
2. Name: `RAG-Chatbot-Test`
3. Type: **Pipeline**
4. Click **OK**

**Configure Pipeline:**

1. In **Pipeline** section, select: **Pipeline script from SCM**
2. SCM: **Git**
3. Repository URL: `https://github.com/your-username/your-repo.git`
4. Branch: `*/main`
5. Script Path: `Jenkinsfile.test`
6. Click **Save**

### Run Test Pipeline

1. Click **Build Now**
2. Watch build in **Console Output**
3. Pipeline validates all dependencies and configurations

**Expected Results:**

```
✓ Code checkout successful
✓ Backend dependencies valid
✓ Chatbot dependencies valid
✓ Frontend dependencies valid
✓ Dockerfiles present and valid
✓ Kubernetes manifests present
✓ Pipeline stages validated

Ready for full CI/CD execution!
```

---

## Creating Full CI/CD Pipeline

### Create Full Pipeline Job

1. Click **New Item**
2. Name: `RAG-Chatbot-CI-CD`
3. Type: **Pipeline**
4. Click **OK**

**Configure Pipeline:**

1. In **Pipeline** section, select: **Pipeline script from SCM**
2. SCM: **Git**
3. Repository URL: Your Git repo URL
4. Branch: `*/main`
5. Script Path: `Jenkinsfile`
6. Click **Save**

### Add Build Parameters

1. Check **This project is parameterized**
2. Add parameters:

**DEPLOYMENT_ENV (Choice)**

- Choices: `staging` `production`
- Default: `staging`

**SKIP_TESTS (Boolean)**

- Default: unchecked

**SKIP_DEPLOY (Boolean)**

- Default: checked (prevents accidental production deploy)

### Run Full Pipeline

1. Click **Build with Parameters**
2. Set parameters:
   - DEPLOYMENT_ENV: `staging`
   - SKIP_TESTS: unchecked
   - SKIP_DEPLOY: checked (for testing without actual deployment)
3. Click **Build**

**Stages:**

1. Checkout code
2. Backend lint & build
3. Chatbot lint & test
4. Frontend lint & build
5. Build Docker images
6. Push Docker images (if on main branch)
7. Deploy to Kubernetes (if enabled and on main branch)
8. Health checks

---

## Testing Scenarios

### Scenario 1: Test Code Quality Only

**Goal:** Verify linting and builds

**Steps:**

1. Click **Build with Parameters**
2. SKIP_DEPLOY: checked
3. SKIP_TESTS: unchecked
4. Build

**What runs:**

- Backend lint & build
- Chatbot lint & test
- Frontend lint & build
- (No Docker or K8s)

---

### Scenario 2: Test Docker Build

**Goal:** Build Docker images locally

**Steps:**

1. Run full pipeline with:
   - SKIP_DEPLOY: checked
   - On any branch (Docker builds on main only by default)

**Verify:**

```bash
docker images | grep test/
```

---

### Scenario 3: Deploy to Staging

**Goal:** Full deployment to K8s staging cluster

**Pre-requisites:**

- Kubernetes cluster running
- kubeconfig configured as Jenkins credential
- Docker Hub credentials configured

**Steps:**

1. Click **Build with Parameters**
2. DEPLOYMENT_ENV: `staging`
3. SKIP_DEPLOY: unchecked
4. Build

**Verify Deployment:**

```bash
kubectl get pods -n rag-chatbot
kubectl get deployments -n rag-chatbot
kubectl logs -f pod/backend-xxx -n rag-chatbot
```

---

### Scenario 4: Test Automatic Rollback

**Goal:** Verify rollback on deployment failure

**Steps:**

1. Trigger deployment
2. Intentionally crash a pod:
   ```bash
   kubectl delete pod -l app=backend -n rag-chatbot
   ```
3. Watch Jenkins console - automatic rollback should trigger
4. Verify previous version restored:
   ```bash
   kubectl get deployment backend -n rag-chatbot -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

---

## Local Testing Without Kubernetes

If no K8s cluster available:

**Test Backend Build:**

```bash
cd backend
npm ci
npm run lint 2>/dev/null || echo "No lint script"
npm run build 2>/dev/null || echo "No build script"
```

**Test Chatbot:**

```bash
cd chatbot
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install flake8
flake8 . --max-line-length=120
```

**Test Frontend:**

```bash
cd frontend
npm ci
npm run lint 2>/dev/null || echo "No lint script"
npm run build
```

**Test Docker Builds:**

```bash
docker build ./backend -t test/rag-backend:local
docker build -f chatbot/Dockerfile . -t test/rag-chatbot:local
docker build ./frontend -t test/rag-frontend:local
```

---

## Viewing Build Artifacts

1. Go to Jenkins job
2. Click build number
3. Click **Artifacts** in left sidebar
4. Download reports and logs

---

## Troubleshooting

### Git Repository Access Error

**Solution:**

1. Verify Git repo URL is correct
2. For private repos, add Git credentials in Jenkins
3. Test:
   ```bash
   git clone <your-repo-url>
   ```

### Docker Build Fails

**Solution:**

1. Verify Docker running: `docker ps`
2. If Jenkins in container, mount Docker socket:
   ```bash
   docker run -v /var/run/docker.sock:/var/run/docker.sock ...
   ```
3. Add Jenkins user to docker group:
   ```bash
   sudo usermod -aG docker jenkins
   ```

### kubectl Connection Error

**Solution:**

1. Verify kubeconfig credential configured
2. Test access:
   ```bash
   kubectl config get-clusters
   kubectl get nodes
   ```
3. Ensure namespace exists:
   ```bash
   kubectl create namespace rag-chatbot
   ```

### "Command not found" (npm, python, docker, etc.)

**Solution:**

1. Verify tools installed
2. Use full paths in Jenkins:
   ```groovy
   sh '/usr/bin/npm ci'
   sh '/usr/bin/python3 -m pytest'
   ```

---

## Stopping Jenkins

```bash
docker-compose -f docker-compose.jenkins.yml down
```

## Removing All Jenkins Data

```bash
docker-compose -f docker-compose.jenkins.yml down -v
```

---

## Key Differences: Jenkins vs GitHub Actions

| Feature         | Jenkins             | GitHub Actions  |
| --------------- | ------------------- | --------------- |
| Setup           | Server required     | Built-in        |
| Triggers        | Manual + webhooks   | Auto on push    |
| Cost            | Self-hosted free    | Free for public |
| Parallelization | Yes                 | Yes             |
| Secrets         | Jenkins credentials | GitHub secrets  |
| Best for        | Enterprise          | Public repos    |

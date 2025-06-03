# RAG-LLM GitOps Deployment Guide for OpenShift AI

## Prerequisites

1. **OpenShift Cluster**: Running in AWS with supported regions:
   - us-east-1, us-east-2, us-west-1, us-west-2
   - ca-central-1, sa-east-1
   - eu-west-1, eu-west-2, eu-west-3, eu-central-1, eu-north-1
   - ap-northeast-1, ap-northeast-2, ap-northeast-3
   - ap-southeast-1, ap-southeast-2, ap-south-1

2. **GPU Nodes**: Required for running the Hugging Face Text Generation Inference server

3. **Podman**: For running deployment scripts

4. **Tools**: `oc` CLI, `helm`, `git`

## Step 1: Repository Setup

### Fork and Clone the Repository

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR-USERNAME/rag-llm-gitops.git
cd rag-llm-gitops
```

### Login to OpenShift

```bash
oc login --token=<your-token> --server=<api-server-url>
```

## Step 2: Configure Secrets

### Setup Model Configuration

```bash
# Copy the secret template
cp values-secret.yaml.template ./values-secret-rag-llm-gitops.yaml
```

Edit `~/values-secret-rag-llm-gitops.yaml`:

```yaml
secrets:
  - name: hfmodel
    fields:
    - name: hftoken
      value: your-huggingface-token-here  # Required for accessing models
    - name: modelId
      value: "ibm-granite/granite-3.3-8b-instruct"
  - name: minio
    fields:
    - name: MINIO_ROOT_USER
      value: minio
    - name: MINIO_ROOT_PASSWORD
      value: your-secure-password  # Or leave null for auto-generation
      onMissingValue: generate
```

**Note**: Get your Hugging Face token from https://huggingface.co/settings/tokens and accept the terms for the model you want to use.

## Step 3: Choose Vector Database Backend

The pattern supports three vector database types. By default, it uses EDB Postgres for Kubernetes. 

### Option A: EDB Postgres for Kubernetes (Default)
No changes needed - this is the default configuration.

### Option B: Redis
Edit `values-global.yaml`:

```yaml
global:
  db:
    index: docs
    type: REDIS  # Change from EDB to REDIS
```

### Option C: Elasticsearch
Edit `values-global.yaml`:

```yaml
global:
  db:
    index: docs
    type: ELASTIC  # Change from EDB to ELASTIC
```

## Step 4: Provision GPU Nodes

### Automated GPU MachineSet Creation

```bash
# This will create GPU nodes with proper taints and labels
./pattern.sh make create-gpu-machineset
```

This command:
- Creates a MachineSet with `g5.2xlarge` instances
- Applies `odh-notebook` taints for GPU workloads
- Adds appropriate labels for node selection
- Takes approximately 5-10 minutes

### Wait for Node Provisioning

```bash
# Monitor node status
oc get nodes --show-labels | grep gpu

# Check that GPU nodes are ready
oc get nodes -l node-role.kubernetes.io/odh-notebook
```

### Manual GPU Setup (Alternative)

If you prefer manual setup, follow the instructions in `GPU_provisioning.md`:

1. **Install Node Feature Discovery Operator**
2. **Install NVIDIA GPU Operator** 
3. **Configure GPU cluster policies**

## Step 5: Deploy the Pattern

### Install the Complete Pattern

```bash
# Deploy all components
./pattern.sh make install
```

This deployment includes:
- **OpenShift AI** (Red Hat OpenShift Data Science)
- **vLLM Text Generation Inference Server** with IBM Granite model
- **Vector Database** (EDB/Redis/Elasticsearch based on configuration)
- **RAG LLM UI Application** 
- **Data Population Job** (populates vector DB with Red Hat documentation)
- **Monitoring Stack** (Prometheus + Grafana)

**Deployment Time**: Approximately 15-20 minutes

## Step 6: Verification

### Check Pod Status

```bash
# Verify all pods are running in rag-llm namespace
oc get pods -n rag-llm
```

Expected pods (with EDB):
- `vectordb-*` (PostgreSQL with pgvector)
- `ui-multiprovider-rag-redis-*` (RAG UI application)
- `ibm-granite-instruct-*` (vLLM inference server)
- `populate-vectordb-*` (completed job)
- Additional MinIO and supporting pods

### Check GPU Inference Server

```bash
# Verify the model inference server is running
oc get pods -n rag-llm | grep granite

# Check logs if needed
oc logs -n rag-llm deployment/ibm-granite-instruct-predictor-default
```

### Access the Application

1. **Find the Route**:
   ```bash
   oc get routes -n rag-llm
   ```

2. **Access via OpenShift Console**:
   - Navigate to Application Launcher (9-dot menu)
   - Click "Retrieval-Augmented Generation (RAG) LLM Demonstration UI"

3. **Test the Application**:
   - Enter company name: `IBM`
   - Enter product: `RedHat OpenShift`
   - Click "Generate" to create a project proposal

## Step 7: Access Monitoring

### Grafana Dashboard

1. **Get Grafana Credentials**:
   ```bash
   # Navigate to Workloads → Secrets in llm-monitoring namespace
   # Copy GF_SECURITY_ADMIN_USER and GF_SECURITY_ADMIN_PASSWORD
   oc get secret grafana-admin-credentials -n llm-monitoring -o yaml
   ```

2. **Access Grafana**:
   - Click Application Launcher → "Grafana UI for LLM Ratings"
   - Login with admin credentials
   - View model performance metrics and ratings

## Configuration Options

### Model Configuration

You can change the model by updating `values-global.yaml`:

```yaml
global:
  model:
    modelId: "your-preferred-model"  # e.g., different Granite variant
```

### Scaling Configuration

Adjust resources in the relevant chart values:

```yaml
# In charts/all/rag-llm/values.yaml
resources:
  limits:
    cpu: '4'      # Increase for better performance
    memory: 4Gi
  requests:
    cpu: '2'
    memory: 2Gi
```

### Adding New Providers

The application supports multiple LLM providers:
- OpenShift AI (vLLM) - Default
- OpenAI 
- NVIDIA NIM

Use the "Add Provider" tab in the UI to configure additional providers.

## Troubleshooting

### Common Issues

1. **GPU Nodes Not Ready**:
   ```bash
   # Check node status and NVIDIA operator
   oc get nodes -l node-role.kubernetes.io/odh-notebook
   oc get pods -n nvidia-gpu-operator
   ```

2. **Model Download Issues**:
   ```bash
   # Check if Hugging Face token is correctly configured
   oc get secret huggingface-secret -n rag-llm -o yaml
   ```

3. **Vector DB Connection Issues**:
   ```bash
   # For EDB Postgres
   oc get clusters.postgresql.k8s.enterprisedb.io -n rag-llm
   
   # For Redis
   oc get pods -n rag-llm | grep redis
   ```

### Logs and Debugging

```bash
# Check application logs
oc logs -n rag-llm deployment/ui-multiprovider-rag-redis

# Check inference server logs  
oc logs -n rag-llm deployment/ibm-granite-instruct-predictor-default

# Check data population job
oc logs -n rag-llm job/populate-vectordb-rag-llm
```

## Cleanup

To remove the pattern:

```bash
./pattern.sh make uninstall
```

## Next Steps

1. **Customize Data Sources**: Modify the data population job to use your own documentation
2. **Integrate with External Systems**: Use the REST API endpoints for integration
3. **Scale Resources**: Adjust CPU/memory based on your workload requirements
4. **Add Custom Models**: Deploy additional model servers as needed

For detailed testing procedures, refer to `TESTPLAN.md` in the repository.
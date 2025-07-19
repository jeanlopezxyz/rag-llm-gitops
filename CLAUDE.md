# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**RAG LLM GitOps** - GitOps deployment repository for the KCD Peru 2025 RAG Chatbot system. This repository manages the Kubernetes/OpenShift deployment configurations using the Validated Patterns framework to deploy a complete RAG (Retrieval-Augmented Generation) chatbot infrastructure with LLM support.

## Architecture

**Deployment Stack:**
- **Validated Patterns Framework**: GitOps-based deployment automation
- **Red Hat OpenShift**: Target platform with GPU support
- **Helm Charts**: Package management for all microservices
- **ArgoCD**: GitOps continuous delivery
- **Operators**: Node Feature Discovery, NVIDIA GPU, EDB Postgres, Elasticsearch, Service Mesh, Serverless

**Components Deployed:**
1. **vLLM Inference Server**: Serves IBM Granite 3.3-8B-Instruct model (GPU required)
2. **Vector Database**: EDB Postgres/Redis/Elasticsearch for embeddings storage
3. **RAG Application Stack**: All 7 microservices from the chatbot system
4. **Monitoring**: Prometheus + Grafana for metrics and dashboards
5. **Infrastructure**: GPU nodes, operators, and supporting services

## Common Development Commands

### Initial Setup
```bash
# Login to OpenShift cluster
oc login --token=<token> --server=<api_server_url>

# Clone and setup repository
git clone https://github.com/<your-org>/rag-llm-gitops.git
cd rag-llm-gitops

# Configure secrets (never commit this file)
cp values-secret.yaml.template ~/values-secret-rag-llm-gitops.yaml
# Edit ~/values-secret-rag-llm-gitops.yaml with your tokens
```

### Deployment Commands
```bash
# Create GPU nodes (required before deployment)
./pattern.sh make create-gpu-machineset

# Full pattern deployment (15-20 minutes)
./pattern.sh make install

# Post-installation tasks
make post-install

# Run tests
make test
```

### Makefile Targets
- `install`: Complete pattern installation with operator deployment and secrets
- `create-gpu-machineset`: Provision GPU-enabled nodes via Ansible
- `post-install`: Load secrets and finalize configuration
- `test`: Run pattern validation tests
- `%`: Proxy to common Makefile for standard targets

## Configuration Structure

### Key Configuration Files
- `values-global.yaml`: Global settings, database type selection, model configuration
- `values-hub.yaml`: Hub cluster configuration, namespaces, operators, applications
- `values-secret.yaml.template`: Template for secrets (HuggingFace tokens, MinIO credentials)
- `pattern-metadata.yaml`: Pattern metadata and requirements
- `ansible.cfg`: Ansible configuration for GPU provisioning

### Database Selection
Configure in `values-global.yaml`:
```yaml
global:
  db:
    type: EDB  # Options: EDB, REDIS, ELASTIC
```

### Model Configuration
Default model: `ibm-granite/granite-3.3-8b-instruct`
Configure in `values-global.yaml` and secrets file

## Helm Charts Structure

### Application Charts (`charts/all/`)
- **rag-llm**: Main RAG application deployment (UI and configuration)
- **rag-llm-agent-core**: Central AI orchestrator with LangChain
- **rag-llm-agenda-api**: REST API for event data
- **rag-llm-mcp-server**: MCP protocol server for agenda tools
- **rag-llm-mcp-vector-server**: MCP server for vector search
- **rag-llm-mcp-graph-server**: MCP server for graph queries
- **llm-serving-service**: vLLM model serving configuration
- **llm-monitoring**: Prometheus/Grafana stack with Kustomize
- **minio**: Object storage for models
- **nfd-config**: Node Feature Discovery configuration
- **nvidia-gpu-config**: NVIDIA GPU operator configuration
- **rag-llm-ui-config**: UI route configuration
- **rhods**: Red Hat OpenShift AI deployment

### Supporting Components
- **edb**: EDB Postgres for Kubernetes
- **elastic**: Elasticsearch operator
- **redis-stack-server**: Redis with vector support

## GPU Provisioning

### Automated Method
```bash
./pattern.sh make create-gpu-machineset
```

### Manual Method (GPU_provisioning.md)
1. Create MachineSet with GPU instance type (e.g., g5.2xlarge)
2. Apply node labels: `node-role.kubernetes.io/odh-notebook`
3. Add taints: `odh-notebook=true:NoSchedule`
4. Verify NVIDIA pods are running on GPU nodes

## Deployment Workflow

### Order of Operations
1. **GPU Provisioning**: Nodes with NVIDIA support
2. **Operators Installation**: NFD, NVIDIA, database operators
3. **Infrastructure**: Databases (PostgreSQL, PGVector, Neo4j), object storage
4. **Model Serving**: vLLM server deployment
5. **Backend Services**: Deploy in order:
   - rag-llm-agenda-api (depends on PostgreSQL)
   - rag-llm-mcp-server (depends on agenda-api)
   - rag-llm-mcp-vector-server (depends on PGVector)
   - rag-llm-mcp-graph-server (depends on Neo4j)
   - rag-llm-agent-core (depends on all MCP servers)
6. **Frontend**: rag-llm UI (depends on agent-core)
7. **Monitoring**: Metrics and dashboards

### Validation Checklist
- [ ] GPU nodes provisioned and labeled
- [ ] NVIDIA pods running on GPU nodes
- [ ] All operators installed and available
- [ ] Database pods running (PostgreSQL, PGVector, Neo4j)
- [ ] All microservice pods in `rag-llm` namespace running:
  - [ ] rag-llm-agenda-api
  - [ ] rag-llm-mcp-server
  - [ ] rag-llm-mcp-vector-server
  - [ ] rag-llm-mcp-graph-server
  - [ ] rag-llm-agent-core
  - [ ] rag-llm-ui
- [ ] Routes accessible for UI and Grafana
- [ ] Model serving endpoint responsive
- [ ] Agent core health check passing

## Testing

### Test Plan (TESTPLAN.md)
- GPU node provisioning validation
- Operator installation verification
- Application deployment checks
- End-to-end functionality testing

### Test Execution
```bash
# Run automated tests
make test

# Check specific namespaces
oc get pods -n rag-llm
oc get pods -n llm-monitoring
oc get pods -n nvidia-gpu-operator
```

## Production Considerations

### Platform Requirements
- **OpenShift**: 4.x on AWS (specific GPU-supported regions)
- **Nodes**: Minimum 3 worker + 1 GPU node
- **Instance Types**: m5.2xlarge (workers), g5.2xlarge (GPU)

### Security
- Secrets managed via External Secrets Operator
- Vault integration for sensitive data
- No hardcoded credentials in charts

### Monitoring
- Grafana dashboards for model performance
- Prometheus metrics for all services
- Custom ServiceMonitors for application metrics

## Troubleshooting

### Common Issues
1. **GPU nodes not ready**: Check MachineSet status and AWS quotas
2. **Model serving fails**: Verify GPU operator and node taints
3. **Database connection errors**: Check PVC status and credentials
4. **ArgoCD sync failures**: Review application logs in ArgoCD UI

### Debug Commands
```bash
# Check GPU operator status
oc get pods -n nvidia-gpu-operator

# Verify node labels and taints
oc get nodes --show-labels | grep gpu

# Check application logs
oc logs -n rag-llm deployment/rag-llm

# Validate secrets
oc get secrets -n rag-llm
```
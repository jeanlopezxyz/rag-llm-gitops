# Guía de Resolución de Problemas - IBM Granite Inference Server

## Diagnóstico del Problema

Los pods están presentando múltiples errores. Vamos a diagnosticar paso a paso:

## Paso 1: Verificar Logs Detallados

```bash
# Ver logs del pod con CrashLoopBackOff
oc logs ibm-granite-instruct-predictor-00001-deployment-7848fd849dc554d -n rag-llm

# Si el pod tiene múltiples contenedores, especifica el contenedor
oc logs ibm-granite-instruct-predictor-00001-deployment-7848fd849dc554d -n rag-llm -c kserve-container

# Ver eventos del namespace
oc get events -n rag-llm --sort-by='.lastTimestamp' | grep granite
```

## Paso 2: Verificar Configuración de GPU

```bash
# Verificar que los nodos GPU estén disponibles
oc get nodes -l node-role.kubernetes.io/odh-notebook

# Verificar que los nodos tengan GPUs
oc describe nodes -l node-role.kubernetes.io/odh-notebook | grep nvidia.com/gpu

# Verificar que NVIDIA operator esté funcionando
oc get pods -n nvidia-gpu-operator

# Verificar que los drivers NVIDIA estén instalados
oc get daemonset -n nvidia-gpu-operator
```

## Paso 3: Verificar Secretos y Configuración

```bash
# Verificar que el secret de Hugging Face existe
oc get secret huggingface-secret -n rag-llm -o yaml

# Verificar el InferenceService
oc get inferenceservice -n rag-llm
oc describe inferenceservice ibm-granite-instruct -n rag-llm

# Verificar ServingRuntime
oc get servingruntime -n rag-llm
oc describe servingruntime ibm-granite-instruct -n rag-llm
```

## Paso 4: Verificar Recursos y Límites

```bash
# Verificar que hay suficientes recursos GPU
oc describe nodes -l node-role.kubernetes.io/odh-notebook | grep -A 5 -B 5 "nvidia.com/gpu"

# Ver estado del accelerator profile
oc get acceleratorprofile -n redhat-ods-applications
```

## Soluciones Comunes

### Solución 1: Recrear el InferenceService

```bash
# Eliminar el InferenceService actual
oc delete inferenceservice ibm-granite-instruct -n rag-llm

# Esperar a que se limpien los pods
oc get pods -n rag-llm | grep granite

# Reinstalar solo el servicio de inferencia
cd rag-llm-gitops
./pattern.sh make install  # Esto recreará todos los componentes
```

### Solución 2: Verificar y Recrear Secretos

```bash
# Recrear el secret de Hugging Face
oc delete secret huggingface-secret -n rag-llm

# Recargar secretos desde el vault
./pattern.sh make load-secrets
```

### Solución 3: Verificar Configuración del Modelo

Edita el archivo `~/values-secret-rag-llm-gitops.yaml` y asegúrate de que:

```yaml
secrets:
  - name: hfmodel
    fields:
    - name: hftoken
      value: "hf_tu_token_aqui"  # Token válido de Hugging Face
    - name: modelId
      value: "ibm-granite/granite-3.3-8b-instruct"
```

Luego recarga:
```bash
./pattern.sh make load-secrets
```

### Solución 4: Verificar Tolerations y Node Affinity

```bash
# Ver la configuración del pod problemático
oc get pod ibm-granite-instruct-predictor-00001-deployment-7848fd849dc554d -n rag-llm -o yaml | grep -A 10 -B 10 toleration

# Verificar que los nodos GPU tengan los taints correctos
oc describe nodes -l node-role.kubernetes.io/odh-notebook | grep Taints
```

### Solución 5: Limpiar Pods Problemáticos

```bash
# Eliminar todos los pods problemáticos
oc get pods -n rag-llm | grep granite | awk '{print $1}' | xargs oc delete pod -n rag-llm

# O eliminar todos los pods del namespace para forzar recreación
oc delete pods --all -n rag-llm
```

## Paso 5: Verificación Completa del Sistema

### Verificar OpenShift AI

```bash
# Verificar que DataScienceCluster esté configurado
oc get datasciencecluster

# Verificar operators de OpenShift AI
oc get pods -n redhat-ods-operator

# Verificar que KServe esté funcionando
oc get pods -n knative-serving
```

### Verificar Knative Serving

```bash
# KServe depende de Knative Serving
oc get knativeserving knative-serving -n knative-serving

# Verificar que los pods de Knative estén corriendo
oc get pods -n knative-serving
```

## Comando de Verificación Final

```bash
# Script completo de verificación
echo "=== Verificando Nodos GPU ==="
oc get nodes -l node-role.kubernetes.io/odh-notebook

echo "=== Verificando NVIDIA Operator ==="
oc get pods -n nvidia-gpu-operator | head -5

echo "=== Verificando OpenShift AI ==="
oc get datasciencecluster

echo "=== Verificando Secretos ==="
oc get secret huggingface-secret -n rag-llm

echo "=== Verificando InferenceService ==="
oc get inferenceservice -n rag-llm

echo "=== Verificando Pods Actuales ==="
oc get pods -n rag-llm | grep granite
```

## Re-despliegue Completo (Si todo lo anterior falla)

```bash
# 1. Limpiar completamente
oc delete namespace rag-llm
oc delete inferenceservice --all -A
oc delete servingruntime --all -A

# 2. Recrear el namespace y volver a desplegar
oc create namespace rag-llm
oc label namespace rag-llm opendatahub.io/dashboard=true
oc label namespace rag-llm modelmesh-enabled=false

# 3. Recargar secretos
./pattern.sh make load-secrets

# 4. Re-desplegar el patrón
./pattern.sh make install
```

## Monitorear el Progreso

```bash
# Monitorear la creación del nuevo pod
watch "oc get pods -n rag-llm | grep granite"

# Ver logs en tiempo real del nuevo pod
oc logs -f deployment/ibm-granite-instruct-predictor-default -n rag-llm
```

## Verificar Éxito del Despliegue

Una vez que el pod esté corriendo correctamente, deberías ver:

```bash
# El pod debe mostrar 2/2 Ready
oc get pods -n rag-llm | grep granite
# Ejemplo: ibm-granite-instruct-predictor-00001-deployment-xxx   2/2   Running   0   5m

# El InferenceService debe mostrar True en Ready
oc get inferenceservice -n rag-llm
# Ejemplo: ibm-granite-instruct   True    http://ibm-granite-instruct-rag-llm...

# Probar el endpoint
curl -X POST http://$(oc get inferenceservice ibm-granite-instruct -n rag-llm -o jsonpath='{.status.url}')/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello", "max_tokens": 10}'
```yq eval . ~/values-secret-rag-llm-gitops.yaml
elimina todos los application applications.argoproj.io

for ns in ai-llm-rag-demo-repo-hub openshift-gitops rag-llm-gitops-hub; do
  for app in $(oc get applications.argoproj.io -n $ns -o jsonpath='{.items[*].metadata.name}'); do
    echo "Eliminando aplicación $app en namespace $ns..."
    oc patch application.argoproj.io $app -n $ns --type merge -p '{"metadata":{"finalizers":[]}}'
    oc delete application.argoproj.io $app -n $ns --force --grace-period=0
  done
done
asegurate que todos los operators inicien

Ejecutar esta solucion para que el namespce pueda crear recrursos desde gitops
https://access.redhat.com/solutions/7026814

# 1. Detener y eliminar TODAS las suscripciones conflictivas
oc delete subscription servicemeshoperator cloud-native-postgresql -n openshift-operators

# 2. Esperar un momento para que OLM procese
sleep 10

# 3. Eliminar TODOS los CSVs huérfanos
oc delete csv servicemeshoperator.v2.6.7 cloud-native-postgresql.v1.23.6 -n openshift-operators

# 4. Eliminar TODOS los InstallPlans
oc get installplan -n openshift-operators -o name | xargs oc delete -n openshift-operators

# 5. Verificar que todo está limpio
oc get subscription,csv,installplan -n openshift-operators



tambien ejecuatr 
/Users/jeanlopez/Documents/proyectos/chatbot-kcd/rag-llm-gitops/commands.sh

luego ejecua el make isntall 
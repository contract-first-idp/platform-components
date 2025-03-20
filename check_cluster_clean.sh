#!/bin/bash

echo "🔍 Checking OpenShift cluster to confirm a clean state..."
echo "=========================================================="

# 0️⃣ Verify OpenShift Cluster Information
echo "🔹 Retrieving OpenShift cluster information..."
CLUSTER_INFO=$(oc cluster-info 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Unable to retrieve cluster information. Are you logged into OpenShift?"
    exit 1
else
    echo "✅ OpenShift cluster information retrieved successfully."
    echo "$CLUSTER_INFO"
fi

CURRENT_USER=$(oc whoami 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Unable to determine current OpenShift user."
    exit 1
else
    echo "✅ Current OpenShift user: $CURRENT_USER"
fi
echo "----------------------------------------------------------"

# Function to check if a resource exists
check_resource() {
    local resource_type=$1
    local namespace=$2
    local name=$3

    echo "➡️ Checking if $resource_type '$name' exists in namespace '$namespace'..."
    oc get "$resource_type" -n "$namespace" | grep -q "$name"
    if [ $? -eq 0 ]; then
        echo "❌ ERROR: $resource_type '$name' is already present in '$namespace'."
        exit 1
    else
        echo "✅ $resource_type '$name' is NOT present."
    fi
}

# 1️⃣ Check OpenShift GitOps Operator
echo "🔹 Checking OpenShift GitOps Operator..."
oc get operators -A | grep -q "openshift-gitops-operator"
if [ $? -eq 0 ]; then
    echo "❌ ERROR: OpenShift GitOps Operator is already installed."
    exit 1
else
    echo "✅ OpenShift GitOps Operator is NOT installed."
fi
echo "----------------------------------------------------------"

# 2️⃣ Check for ArgoCD instance
echo "🔹 Checking for existing ArgoCD instance..."
oc get pods -n openshift-gitops | grep -q "argocd"
if [ $? -eq 0 ]; then
    echo "❌ ERROR: ArgoCD instance already exists."
    exit 1
else
    echo "✅ No ArgoCD instance found."
fi
echo "----------------------------------------------------------"

# 3️⃣ Check for ArgoCD routes
echo "🔹 Checking for existing ArgoCD routes..."
oc get routes -n openshift-gitops | grep -q "argocd"
if [ $? -eq 0 ]; then
    echo "❌ ERROR: ArgoCD route already exists."
    exit 1
else
    echo "✅ No ArgoCD route found."
fi
echo "----------------------------------------------------------"

# 4️⃣ Check for ArgoCD applications
echo "🔹 Checking for existing ArgoCD applications..."
APPS=("apicurio-registry" "apicurito")  # Add all apps from argocd/
for app in "${APPS[@]}"; do
    echo "➡️ Checking if ArgoCD application '$app' is installed..."
    oc get applications -n openshift-gitops | grep -q "$app"
    if [ $? -eq 0 ]; then
        echo "❌ ERROR: ArgoCD application '$app' is already installed."
        exit 1
    else
        echo "✅ ArgoCD application '$app' is NOT present."
    fi
done
echo "----------------------------------------------------------"

# 5️⃣ Check for Helm chart deployments
echo "🔹 Checking for existing Helm chart deployments..."
HELM_CHARTS=("apicurio-registry" "apicurito")  # Add all Helm charts from charts/
for chart in "${HELM_CHARTS[@]}"; do
    echo "➡️ Checking if Helm chart '$chart' is deployed..."
    helm list -A | grep -q "$chart"
    if [ $? -eq 0 ]; then
        echo "❌ ERROR: Helm chart '$chart' is already deployed."
        exit 1
    else
        echo "✅ Helm chart '$chart' is NOT deployed."
    fi
done
echo "----------------------------------------------------------"

# 6️⃣ Check for existing namespaces related to platform components
echo "🔹 Checking for existing platform component namespaces..."
PLATFORM_NAMESPACES=("argocd" "developer-charts" "software-templates" "demo-domain" "spectral-rules")
for ns in "${PLATFORM_NAMESPACES[@]}"; do
    echo "➡️ Checking if namespace '$ns' exists..."
    oc get namespace "$ns" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "❌ ERROR: Namespace '$ns' already exists."
        exit 1
    else
        echo "✅ Namespace '$ns' is NOT present."
    fi
done
echo "----------------------------------------------------------"

# 7️⃣ Check for any lingering deployments, statefulsets, or services
echo "🔹 Checking for existing deployments, statefulsets, and services..."
oc get deployments,statefulsets,services -A | grep -E "apicurio|apicurito" &>/dev/null
if [ $? -eq 0 ]; then
    echo "❌ ERROR: Some deployments, statefulsets, or services related to the apps still exist."
    exit 1
else
    echo "✅ No lingering deployments, statefulsets, or services found."
fi
echo "=========================================================="
echo "🎉 All checks passed! The cluster is clean and ready for installation."

#!/bin/bash

# Source user inputs
source user_input.env

function get_registry_details() {
    #echo "Connecting to bootstrap node..."
    registry_output=$(ssh -o StrictHostKeyChecking=no core@bootstrap "sudo podman images | grep registry")
    registry_url=$(echo "$registry_output" | awk '{print $1}')
    local local_registry_url=(${registry_url//// })
    echo $local_registry_url
}


function get_base64() {
    auth_value=$(jq -r '.auths."registry.arpan-automation-417.ibm.com:5000".auth' ~/.openshift/pull-secret-updated)
    if [[ -z "$auth_value" ]]; then
        echo "No base64 encoded auth found for the registry URL."
        exit 1
    fi
    #echo $auth_value
    login_details=$(echo $auth_value | base64 -d)
    echo $login_details
}




function login_local_registry() {
    echo "Logging into local registry..."
    local auth_token=$(get_base64)
    local username=$(echo $auth_token | cut -d':' -f1)
    local password=$(echo $auth_token | cut -d':' -f2)
    podman login $(get_registry_details) --username $username --password $password
    if [[ $? -ne 0 ]]; then
        echo "Failed to log into the local registry."
        exit 1
    fi
}


function create_authfile() {
    if ! command -v oc &> /dev/null; then
        echo "oc command not found. Please install OpenShift CLI."
        exit 1
    fi

    echo "Creating authfile from updated pull-secret..."
    local pull_secret=$(oc get secret/pull-secret -n openshift-config -o json | jq -r '.data.".dockerconfigjson"' | base64 -d)
    echo "$pull_secret" > /root/authfile
}


function validate_setup() {
    echo "Validating setup..."
    if [[ -f "/run/user/0/containers/auth.json" ]]; then
        echo "Authfile exists at /run/user/0/containers/auth.json"
        cat /run/user/0/containers/auth.json
    else
        echo "Authfile does not exist, login may have failed."
    fi
}

function local_registry_checkup() {
	

IMAGE_SOURCE="quay.io/powercloud/rsct-ppc64le:latest"
LOCAL_REGISTRY="$LOCAL_REGISTRY/rsct-ppc64le:latest"
PULL_SECRET="/root/.openshift/pull-secret-updated"
NAMESPACE="powervm-rmc"
DAEMONSET_NAME="powervm-rmc"


echo "Mirroring image to local registry..."
oc image mirror -a "$PULL_SECRET" "$IMAGE_SOURCE" "$LOCAL_REGISTRY"
if [ $? -ne 0 ]; then
  echo "Image mirroring failed!"
  exit 1
fi
echo "Image mirrored successfully."


echo "Checking DaemonSet status before update..."
oc get ds -n "$NAMESPACE"
if [ $? -ne 0 ]; then
  echo "Failed to get DaemonSet status!"
  exit 1
fi


echo "Editing DaemonSet to use local registry image..."
oc patch ds "$DAEMONSET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/image\", \"value\":\"$LOCAL_REGISTRY\"}]"
if [ $? -ne 0 ]; then
  echo "Failed to edit DaemonSet!"
  exit 1
fi
echo "DaemonSet edited successfully."


echo "Verifying DaemonSet status after update..."
oc get ds "$DAEMONSET_NAME" -n "$NAMESPACE" -o yaml | grep "image:"
if [ $? -ne 0 ]; then
  echo "Failed to verify DaemonSet status!"
  exit 1
fi


echo "Verifying pod statuses..."
oc get pods --all-namespaces | grep rmc
if [ $? -ne 0 ]; then
  echo "Failed to verify pod statuses!"
  exit 1
fi
echo "All RMC pods are running."

echo "Local registry check completed successfully."

}
function Settingup_prerequisites(){
   
# Fixed variables
PULL_SECRET_SOURCE=".openshift/pull-secret-updated"
AUTH_SOURCE="openstack-upi/auth/"
OC_BINARY_SOURCE="/usr/local/bin/oc"
AUTH_YAML_PATH="/root/auth.yaml"
# Clone repository
echo "Cloning repository..."
git clone $REPO_URL
cd ocs-upi-kvm/
echo "Initializing submodules..."
git submodule update --init
# Prepare the workspace
echo "Preparing the workspace..."
cd
cp $PULL_SECRET_SOURCE pull-secret.txt
cp -r $AUTH_SOURCE .
mkdir -p bin
cp $OC_BINARY_SOURCE bin/
cd bin
./oc version
cd
# Create auth.yaml
echo "Creating auth.yaml..."
echo "$AUTH_YAML_CONTENT" > $AUTH_YAML_PATH
# Run setup script
echo "Running setup-ocs-ci.sh script..."
cd ocs-upi-kvm/scripts/
./setup-ocs-ci.sh 2>&1 | tee -a setup-ocs-ci.log
echo "Execution completed."
}

function deploy_ocs_ci(){


OC_MIRROR_URL="https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/$OCP_VERSION/oc-mirror.rhel9.tar.gz"
OPM_URL="https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/$OCP_VERSION/opm-linux-$OCP_VERSION.tar.gz"
OCS_CI_REPO="/root/ocs-upi-kvm/src/ocs-ci"
OCS_CI_SCRIPT="/root/ocs-upi-kvm/scripts/deploy-ocs-ci.sh"
# Install oc-mirror
echo "Installing oc-mirror..."
wget $OC_MIRROR_URL -O oc-mirror.tar.gz
tar -C /usr/local/bin -xvf oc-mirror.tar.gz
chmod +x /usr/local/bin/oc-mirror
oc-mirror version
# Install opm
echo "Installing opm..."
wget $OPM_URL -O opm.tar.gz
tar -C /usr/local/bin -xvf opm.tar.gz
chmod +x /usr/local/bin/opm
opm version
# Configure ocs-ci
echo "Configuring ocs-ci..."
cd $OCS_CI_REPO
sed -i 's/mirror_registry: .*/mirror_registry: "registry.arpan-automation-417.ibm.com:5000"/' conf/ocsci/disconnected_cluster.yaml.example
sed -i 's/mirror_registry_user: .*/mirror_registry_user: "admin"/' conf/ocsci/disconnected_cluster.yaml.example
sed -i 's/mirror_registry_password: .*/mirror_registry_password: "admin"/' conf/ocsci/disconnected_cluster.yaml.example
sed -i 's/^  #http_proxy:/  #http_proxy:/' conf/ocsci/disconnected_cluster.yaml.example
sed -i '/force_download_client: False/a\  opm_index_prune_binary_image: "registry.redhat.io/openshift4/ose-operator-registry:latest"' conf/ocsci/production_powervs_upi.yaml
sed -i 's/# "lvms-operator"/"local-storage-operator"/' ocs_ci/ocs/constants.py
# Modify deployment script
echo "Modifying deployment script..."
sed -i '/--ocsci-conf conf\/ocsci\/manual_subscription_plan_approval.yaml/a\       --ocsci-conf conf\/ocsci\/disconnected_cluster.yaml.example \\' $OCS_CI_SCRIPT
# Set environment variables
echo "Setting environment variables..."
export OCS_REGISTRY_IMAGE=$OCS_REGISTRY_IMAGE
export RHID_USERNAME=$RHID_USERNAME
export RHID_PASSWORD=$RHID_PASSWORD
export OCP_VERSION=$OCP_VERSION
export OCS_VERSION=$OCS_VERSION
export PLATFORM=$PLATFORM
export VAULT_SUPPORT=$VAULT_SUPPORT
export FIPS_ENABLEMENT=$FIPS_ENABLEMENT
# Run deployment script
echo "Running deployment script..."
cd /root/ocs-upi-kvm/scripts/
nohup ./deploy-ocs-ci.sh 2>&1 | tee -a deploy-ocs-ci.log
echo "Deployment script is running in the background. Check deploy-ocs-ci.log for progress."


}

function validatio_cluster(){
    
check_nodes() {
    echo "Checking node status..."
    oc get nodes
    echo ""
}


check_cluster_version() {
    echo "Checking cluster version..."
    oc get clusterversion
    echo ""
}


check_oc_version() {
    echo "Checking oc client and server versions..."
    oc version
    echo ""
}


check_csvs() {
    echo "Checking ClusterServiceVersions (CSVs)..."
    oc get csv -A
    echo ""
}


check_odf_operator_version() {
    echo "Checking ODF operator full version..."
    oc get csv odf-operator.v4.16.0-rhodf -n openshift-storage -o yaml | grep full_version
    echo ""
}


check_local_storage_pods() {
    echo "Checking pods in openshift-local-storage namespace..."
    oc get pods -n openshift-local-storage
    echo ""
}


check_localvolumeset() {
    echo "Checking local volume sets..."
    oc get localvolumeset -n openshift-local-storage
    oc get localvolumeset -n openshift-local-storage -o yaml
    echo ""
}


check_pv() {
    echo "Checking persistent volumes..."
    oc get pv
    echo ""
}


check_storage_pods() {
    echo "Checking pods in openshift-storage namespace..."
    oc get pods -n openshift-storage
    echo ""
}


check_pvc() {
    echo "Checking persistent volume claims in openshift-storage namespace..."
    oc get pvc -n openshift-storage
    echo ""
}


check_sc() {
    echo "Checking storage classes..."
    oc get sc -n openshift-storage
    echo ""
}


check_storagecluster() {
    echo "Checking storage cluster..."
    oc get storagecluster -n openshift-storage
    echo ""
}


check_cephcluster() {
    echo "Checking Ceph cluster..."
    oc get cephcluster -n openshift-storage
    echo ""
}


check_storagesystem() {
    echo "Checking storage systems..."
    oc get storagesystem -n openshift-storage
    echo ""
}


main() {
    check_nodes
    check_cluster_version
    check_oc_version
    check_csvs
    check_odf_operator_version
    check_local_storage_pods
    check_localvolumeset
    check_pv
    check_storage_pods
    check_pvc
    check_sc
    check_storagecluster
    check_cephcluster
    check_storagesystem
}


main

}

function main() {
    echo "Starting OpenShift local registry and storage setup..."

    get_registry_details
    login_local_registry
    validate_setup
    create_authfile
    local_registry_checkup
    Settingup_prerequisites
    deploy_ocs_ci
    validatio_cluster
    echo "Setup completed."
}

main



# Disconnected Cluster Validation Setup

## Steps to Setup the Disconnected Cluster Validation

Follow these steps to create a cluster, clone the repository, and run the validation script.

### 1. Create a Cluster
Ensure that your cluster is created and accessible.

### 2. Clone the Repository
Clone the repository to your local machine using the following command:

```bash
git clone <your-repository-url>
cd <your-repository-directory>
# Disconected_Cluster_Validation
```

### 3. Modify the user_input.env File
Before running the main.sh script, you need to fill out the user_input.env file with the necessary configuration.

Here is the format for the user_input.env file:


```bash
# User Input Variables

LOCAL_REGISTRY="    "      ### Please provide your local registry URL 
REPO_URL="      "          ##### Please provide your local repository URL
AUTH_YAML_CONTENT=$()      #### Please provide your Auth file credential
OCP_VERSION="   "          #### Please provide the OpenShift version (e.g., 4.16.1, 4.17.2, 4.18.0)
OCS_REGISTRY_IMAGE="    "  #### Please provide your OCS registry image
RHID_USERNAME="     "      #### Please provide your RHID username
RHID_PASSWORD="     "      #### Please provide your RHID password
OCS_VERSION="   "          #### Please provide your OCS version (e.g., 4.16, 4.17, 4.18)
```

### Local Registry URL
To find your local registry URL, run the following command:

```bash
sudo podman images
```
This will return a list of images. You can find your local registry URL as shown below:

```bash
Local registry:  `registry.arpan-automation-417.ibm.com:5000`
```
For example:

```bash
[root@arpan-automation-417-bastion-0 code_4]# ssh -oStrictHostKeyChecking=no core@bootstrap
[core@bootstrap ~]$ sudo podman images | grep registry
registry.arpan-automation-417.ibm.com:5000/ocp4/openshift4  4.16.0-rc.9-ppc64le  6964b47e75b0  6 months ago  554 MB
```
### 4. Modify the main.sh Script
In the main.sh script, you need to manually change the image in line 16 to match your local registry URL.

Find the following line:

```bash
auth_value=$(jq -r '.auths."#### PUT LOCAL REGISTRY HERE #### ".auth' ~/.openshift/pull-secret-updated)
```
And replace #### PUT LOCAL REGISTRY HERE #### with the appropriate registry URL you found earlier. For example:

```bash
auth_value=$(jq -r '.auths."registry.arpan-automation-417.ibm.com:5000".auth' ~/.openshift/pull-secret-updated)
```
### 5. Run the main.sh Script
Once the user_input.env file and main.sh script are properly configured, you can run the script using the following command:

```bash
bash main.sh
```
### Notes
 * Make sure that the required tools (e.g., jq, podman) are installed and configured on your system.
 * Ensure that the OpenShift cluster is properly set up and accessible before running the script.


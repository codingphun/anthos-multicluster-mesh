#!/usr/bin/env bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Variables
export PROJECT=$(gcloud config get-value project)
export PROJECT_ID=${PROJECT}
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
export WORK_DIR=${WORK_DIR:="${PWD}/workdir"}


export CLUSTER_NAME="gke-asm-2"
export CLUSTER_ZONE="us-central1-b"
export CLUSTER_KUBECONFIG=$WORK_DIR/${CLUSTER_NAME}.context
export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
export MESH_ID=proj-${PROJECT_NUMBER}

gcloud config set compute/zone ${CLUSTER_ZONE}


echo "### "
echo "### Begin Provision GKE"
echo "### "
## Check if cluster already exists to avoid errors
EXISTING_CLUSTER=$(gcloud container clusters list --format="value(name)" --filter="name ~ ${CLUSTER_NAME} AND location:${CLUSTER_ZONE}")
if [ "${EXISTING_CLUSTER}" == "${CLUSTER_NAME}" ]; then
    echo "Cluster already created."
else
    echo "Creating cluster..."
    gcloud beta container clusters create ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} \
        --machine-type=e2-standard-4 \
        --num-nodes=4 \
        --enable-stackdriver-kubernetes \
        --subnetwork=default \
        --workload-pool=${WORKLOAD_POOL} \
        --labels mesh_id=${MESH_ID}
fi

echo "Getting cluster credentials"
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE}

echo "Renaming kubectx context to ${CLUSTER_NAME} and switching to context"
kubectx ${CLUSTER_NAME}=gke_${PROJECT}_${CLUSTER_ZONE}_${CLUSTER_NAME}
kubectx ${CLUSTER_NAME}

KUBECONFIG= kubectl config view --minify --flatten --context=$CLUSTER_NAME > $CLUSTER_KUBECONFIG


echo "Creating clusterrolebinding"
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"

echo "### "
echo "### Provision GKE complete, installing ASM 1.7"
echo "### "

## Install kpt
if command -v kpt 2>/dev/null; then
	echo "kpt already installed."
else
	echo "Installing kpt..."
	sudo apt-get install google-cloud-sdk-kpt
fi


curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.7 > install_asm
chmod +x install_asm
./install_asm \
  --project_id ${PROJECT_ID} \
  --cluster_name ${CLUSTER_NAME} \
  --cluster_location ${CLUSTER_ZONE} \
  --mode install \
  --enable_apis


#to delete
#istioctl manifest generate --set profile=asm-gcp | kubectl delete --ignore-not-found=true -f -
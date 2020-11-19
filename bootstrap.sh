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
# if using service account, make sure proper permission such as Editor, Security Admin, Kube Engine Admin roles are provisioned

if [[ $OSTYPE == "linux-gnu" ]]; then
    echo "⚡️ Starting Anthos environment install."
    export PROJECT=$(gcloud config get-value project)
    export BASE_DIR=${BASE_DIR:="${PWD}"}
    export WORK_DIR=${WORK_DIR:="${BASE_DIR}/workdir"}

    echo "WORK_DIR set to $WORK_DIR"
    gcloud config set project $PROJECT

    echo "🛠 Installing client tools."
    ./install-tools.sh

    echo "🔆 Enabling GCP APIs. This may take up to 5 minutes."
    gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    stackdriver.googleapis.com \
    meshca.googleapis.com \
    meshtelemetry.googleapis.com \
    meshconfig.googleapis.com \
    iamcredentials.googleapis.com \
    anthos.googleapis.com \
    cloudresourcemanager.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    serviceusage.googleapis.com 

    if ! command -v kops &> /dev/null 
    then
        echo "COMMAND could not be found"
        exit
    fi

    echo "☸️ Creating 2 Kubernetes clusters in parallel."
    echo -e "\nMultiple tasks are running asynchronously to setup your environment.  It may appear frozen, but you can check the logs in $WORK_DIR for additional details in another terminal window."
    ./gke-provision.sh &> ${WORK_DIR}/gke-provision.log &
    ./onprem-k8s-provision.sh &> ${WORK_DIR}/onprem-provision.log &
    wait

    # generate kops kubecfg
    echo "🎢 setup onprem firewall."
    ./onprem-k8s-access-fw.sh

    # install service mesh: Istio, replicated control plane multicluster
    echo "🕸 Installing service mesh on both clusters."
    CONTEXT="gke" ./istio-install.sh
    CONTEXT="onprem" ./istio-install.sh

    # configure DNS stubdomains for cross-cluster service name resolution
    echo "🌏 Connecting the 2 Istio control planes into one mesh."
    CONTEXT="gke"  ./istio-coredns.sh
    CONTEXT="onprem"  ./istio-coredns.sh

    # install GKE connect on both clusters / print onprem login token
    #echo "⬆️ Installing GKE Connect on both clusters."
    #./gke-connect-hub.sh
    #./onprem-k8s-connect-hub.sh

    echo "✅ Bootstrap script complete."
else
    echo "This has only been tested in GCP Cloud Shell.  Only Linux (debian) is supported".
fi

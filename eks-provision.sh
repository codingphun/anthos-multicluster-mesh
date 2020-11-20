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

# Pre-reqs - install aws cli, eksctl and configure aws config
# follow instructions from https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html#install-awscli
export AWS_USER="AWS_USER"

export WORK_DIR=${WORK_DIR:="${PWD}/workdir"}
export CLUSTER_NAME="anthos-attached-eks-tli-1"
export CLUSTER_ZONE="us-east-2"
export CLUSTER_WORKER_GROUP="ng-workers-tli-1"

export KUBE_CTX="eks"
export CLUSTER_KUBECONFIG=$WORK_DIR/${CLUSTER_NAME}.context
export KUBECONFIG=${CLUSTER_KUBECONFIG}

eksctl create cluster \
    --name ${CLUSTER_NAME} \
    --version 1.18 \
    --region ${CLUSTER_ZONE} \
    --nodegroup-name ${CLUSTER_WORKER_GROUP} \
    --nodes 3 \
    --nodes-min 1 \
    --nodes-max 4 \
    --set-kubeconfig-context=true \
    --managed

echo "Creating clusterrolebinding"
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"

echo "Renaming kubectx context to ${KUBE_CTX} and switching to context"
kubectx ${KUBE_CTX}=${AWS_USER}@${CLUSTER_NAME}.${CLUSTER_ZONE}.eksctl.io
kubectx ${KUBE_CTX}


### Connect Cluster to Hub
#gcloud container hub memberships register anthos-attached-eks-tli-1 \
# --context=eks \
# --service-account-key-file=${PWD}/workdir/anthos-connect-creds.json \
# --kubeconfig=${PWD}/workdir/anthos-attached-eks-tli-1.context \
# --project=$(gcloud config get-value project)


## Create Service Account for use in Login Step
#export KSA=onprem-admin-sa
#kubectl create serviceaccount $KSA
#kubectl create clusterrolebinding ksa-admin-binding --clusterrole cluster-admin --serviceaccount default:$KSA

# Generate Token for login process
#echo "###########################"
#echo "Use the following token during login at https://console.cloud.google.com/kubernetes/list for cluster $ONPREM_KUBECONFIG"
#printf "\n$(kubectl --kubeconfig=$ONPREM_KUBECONFIG describe secret $KSA | sed -ne 's/^token: *//p')\n\n"

#to delete - eksctl delete cluster --name ${CLUSTER_NAME}
#make sure and delete node first then cluster in CloudFormation section, if cluster failed to delete the VPC, delete the VPC then try again
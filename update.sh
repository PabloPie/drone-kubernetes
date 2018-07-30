#!/bin/bash

if [ -z ${PLUGIN_NAMESPACE} ]; then
  PLUGIN_NAMESPACE="stage"
fi

if [ -z ${PLUGIN_KUBERNETES_USER} ]; then
  PLUGIN_KUBERNETES_USER="admin"
fi

if [ ! -z ${PLUGIN_KUBERNETES_TOKEN} ]; then
  KUBERNETES_TOKEN=$PLUGIN_KUBERNETES_TOKEN
fi

if [ ! -z ${PLUGIN_KUBERNETES_SERVER} ]; then
  KUBERNETES_SERVER=$PLUGIN_KUBERNETES_SERVER
fi

if [ ! -z ${PLUGIN_KUBERNETES_CERT} ]; then
  KUBERNETES_CERT=${PLUGIN_KUBERNETES_CERT}
fi

## Setup Kubectl to connect to K8S cluster
if [[ ! -z ${KUBERNETES_CLIENT_CRT} ]] && [[ ! -z ${KUBERNETES_CLIENT_KEY} ]]; then
  echo ${KUBERNETES_CLIENT_CRT} | base64 -d > client.crt
  echo ${KUBERNETES_CLIENT_KEY} | base64 -d > client.key
  kubectl config set-credentials admin --client-certificate=client.crt --client-key=client.key
else
  echo "KUBERNETES_CLIENT_KEY OR KUBERNETES_CLIENT_CRT not set"
  exit 1
fi

if [[ ! -z ${KUBERNETES_CERT} ]]; then
  echo ${KUBERNETES_CERT} | base64 -d > ca.crt
  kubectl config set-cluster stage --server=${KUBERNETES_SERVER} --certificate-authority=ca.crt
else
  echo "WARNING: Using insecure connection to cluster"
  kubectl config set-cluster stage --server=${KUBERNETES_SERVER} --insecure-skip-tls-verify=true
fi

kubectl config set-context default --cluster=stage --user=${PLUGIN_KUBERNETES_USER}
kubectl config use-context default

## Update deployment
IFS=',' read -r -a DEPLOYMENTS <<< "${PLUGIN_DEPLOYMENT}"
IFS=',' read -r -a CONTAINERS <<< "${PLUGIN_CONTAINER}"
for DEPLOY in ${DEPLOYMENTS[@]}; do
  echo Deploying to $KUBERNETES_SERVER
  for CONTAINER in ${CONTAINERS[@]}; do
    if [[ ${PLUGIN_STRATEGY} == "modify" ]]; then
      kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
        ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG}
    elif [[ ${PLUGIN_STRATEGY} == "update" ]]; then
      kubectl patch deployment -n ${PLUGIN_NAMESPACE}  ${DEPLOY} \
      -p '{"spec":{"template":{"spec":{"containers":[{"name":"'${CONTAINER}'","env":[{"name":"RESTART_","value":"'$(date +%s)'"}]}]}}}}'
    fi
  done
done

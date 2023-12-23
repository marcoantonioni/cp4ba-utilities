#!/bin/bash

_me=$(basename "$0")

_CP4BA_NAMESPACE=""

source ./_cp4ba-commons.sh

#--------------------------------------------------------
# read command line params
while getopts n: flag
do
    case "${flag}" in
        n) _CP4BA_NAMESPACE=${OPTARG};;
    esac
done

if [[ -z "${_CP4BA_NAMESPACE}" ]]; then
  echo "usage: $_me -n namespace-to-be-removed"
  exit
fi

removeOwnersAndFinalizers() {
  TNS=$1
  TYPE=$2
  oc get -n ${TNS} ${TYPE} --no-headers 2> /dev/null | awk '{print $1}' | xargs oc patch -n ${TNS} ${TYPE} --type=merge -p '{"metadata": {"ownerReferences":null}}' 2> /dev/null
  oc get -n ${TNS} ${TYPE} --no-headers 2> /dev/null | awk '{print $1}' | xargs oc patch -n ${TNS} ${TYPE} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null

}

deleteObject() {
  TNS=$1
  TYPE=$2
  echo "#-----------------------------------------"
  echo "Deleting objects of type: ${TYPE} ..."
  oc get ${TYPE} -n ${TNS} --no-headers 2> /dev/null | awk '{print $1}' | xargs oc delete ${TYPE} -n ${TNS} --wait=false 2> /dev/null
  removeOwnersAndFinalizers ${TNS} ${TYPE}
}

deleteCp4baNamespace () {
  TNS=$1
  CR_NAME=$(oc get ICP4ACluster -n ${TNS} --no-headers  2> /dev/null | awk '{print $1}')
  if [[ ! -z "${CR_NAME}" ]]; then
    oc delete ICP4ACluster -n ${TNS} ${CR_NAME} 2> /dev/null
  fi

  declare -a _types=("csv" "cm" "secret" "service" "route" "deployment" "pod" "rs" "job" "zenextensions.zen.cpd.ibm.com" "clients.oidc.security.ibm.com" "operandrequests.operator.ibm.com" "operandbindinfos.operator.ibm.com" "authentications.operator.ibm.com" "pvc" "pv")
  for _t in "${_types[@]}"
  do
    deleteObject ${TNS} ${_t}
  done

# # echo "Y" | ./cp4a-uninstall-clean-up.sh
#
# deleteObject ${TNS} "csv"
# deleteObject ${TNS} "cm"
# deleteObject ${TNS} "secret"
# deleteObject ${TNS} "service"
# deleteObject ${TNS} "route"
# deleteObject ${TNS} "deployment"
# deleteObject ${TNS} "pod"
# deleteObject ${TNS} "rs"
# deleteObject ${TNS} "job"
#
# deleteObject ${TNS} "zenextensions.zen.cpd.ibm.com"
# sleep 0.5
#
# deleteObject ${TNS} "clients.oidc.security.ibm.com"
# sleep 0.5  
#
# deleteObject ${TNS} "operandrequests.operator.ibm.com"
# sleep 0.5
#
# deleteObject ${TNS} "operandbindinfos.operator.ibm.com"
# sleep 0.5  
#
# deleteObject ${TNS} "authentications.operator.ibm.com"
# sleep 0.5
#
# deleteObject ${TNS} "pvc"
# sleep 0.5  
#
# deleteObject ${TNS} "pv"
# sleep 0.5  

  oc delete ns ${TNS} --wait=false 2> /dev/null
  sleep 0.5
  while [ true ];
  do
    namespaceExist ${TNS}
    if [ $? -eq 1 ]; then
      oc patch ns ${TNS} --type='merge' -p '{"spec": {"finalizers":null}}' 2> /dev/null
      sleep 0.5
    else
      break
    fi
  done
}

#===========================================================

echo "Removing namespace: "${_CP4BA_NAMESPACE}
namespaceExist ${_CP4BA_NAMESPACE}
if [ $? -eq 1 ]; then
  deleteCp4baNamespace ${_CP4BA_NAMESPACE}
  echo "Namespace ${_CP4BA_NAMESPACE} removed."
else
  echo "ERROR: namespace ${_CP4BA_NAMESPACE} doesn't exist."
fi
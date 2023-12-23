#!/bin/bash

_me=$(basename "$0")

_CP4BA_NAMESPACE=""

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

#-------------------------------
# CP4BA Resource types
declare -a _pakResources=(csv cm secret service route deployment pod rs job zenextensions.zen.cpd.ibm.com clients.oidc.security.ibm.com operandrequests.operator.ibm.com operandbindinfos.operator.ibm.com authentications.operator.ibm.com pvc pv)

#-------------------------------
resourceExist () {
# namespace name: $1
# resource type: $2
# resource name: $3
  if [ $(oc get $2 -n $1 $3 2> /dev/null | grep $3 | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

#-------------------------------
namespaceExist () {
# ns name: $1
  if [ $(oc get ns -n $1 2> /dev/null | grep $1 | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

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
  echo "Deleting objects of type '${TYPE}' from ns '${TNS}' ..."
  oc get ${TYPE} -n ${TNS} --no-headers 2> /dev/null | awk '{print $1}' | xargs oc delete ${TYPE} -n ${TNS} --wait=false 2> /dev/null
  removeOwnersAndFinalizers ${TNS} ${TYPE}
}

deleteCp4baNamespace () {
  TNS=$1
  CR_NAME=$(oc get ICP4ACluster -n ${TNS} --no-headers  2> /dev/null | awk '{print $1}')
  if [[ ! -z "${CR_NAME}" ]]; then
    oc delete ICP4ACluster -n ${TNS} ${CR_NAME} 2> /dev/null
  fi

  for _type in "${_pakResources[@]}"
  do
    deleteObject ${TNS} ${_type}
  done

  oc delete ns ${TNS} --wait=false 2> /dev/null
  sleep 1
  
  _patchLoop=30
  until [ $_patchLoop -gt 0 ]
  do
    echo "_patchLoop: "$_patchLoop
    ((_patchLoop=_patchLoop-1))
    namespaceExist ${TNS}
    if [ $? -eq 1 ]; then
      oc patch ns ${TNS} --type='merge' -p '{"spec": {"finalizers":null}}' 2> /dev/null
      sleep 2
    else
      break
    fi
  done  
  namespaceExist ${TNS}
  if [ $? -eq 1 ]; then
    deleteCp4baNamespace ${TNS}
  fi
}

#===========================================================
echo "#========================================="
echo "Removing namespace: "${_CP4BA_NAMESPACE}
namespaceExist ${_CP4BA_NAMESPACE}
if [ $? -eq 1 ]; then
  deleteCp4baNamespace ${_CP4BA_NAMESPACE}
  echo "Namespace ${_CP4BA_NAMESPACE} removed."
else
  echo "ERROR: namespace ${_CP4BA_NAMESPACE} doesn't exist."
fi
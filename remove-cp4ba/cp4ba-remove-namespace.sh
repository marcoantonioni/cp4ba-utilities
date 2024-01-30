#!/bin/bash

########################################################
# example: ./cp4ba-remove-namespace.sh -n cp4ba
########################################################

_me=$(basename "$0")

_CP4BA_NAMESPACE=""

#--------------------------------------------------------
_CLR_RED='\033[0;31m'   #'0;31' is Red's ANSI color code
_CLR_GREEN='\033[0;32m'   #'0;32' is Green's ANSI color code
_CLR_YELLOW='\033[1;32m'   #'1;32' is Yellow's ANSI color code
_CLR_BLUE='\033[0;34m'   #'0;34' is Blue's ANSI color code
_CLR_NC='\033[0m'

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
# do not remove: pv
declare -a _pakResources=(csv deployment job cm secret service route rs pod zenextensions.zen.cpd.ibm.com clients.oidc.security.ibm.com operandrequests.operator.ibm.com operandbindinfos.operator.ibm.com authentications.operator.ibm.com icp4aoperationaldecisionmanagers.icp4a.ibm.com pvc)

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
  if [ $(oc get ns $1 2> /dev/null | grep $1 | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

#-------------------------------
removeOwnersAndFinalizers() {
  TNS=$1
  TYPE=$2
  oc get -n ${TNS} ${TYPE} --no-headers 2> /dev/null | awk '{print $1}' | xargs oc patch -n ${TNS} ${TYPE} --type=merge -p '{"metadata": {"ownerReferences":null}}' 2> /dev/null
  oc get -n ${TNS} ${TYPE} --no-headers 2> /dev/null | awk '{print $1}' | xargs oc patch -n ${TNS} ${TYPE} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
}

#-------------------------------
deleteObject() {
  TNS=$1
  TYPE=$2
  echo "#-----------------------------------------"
  echo -e "${_CLR_GREEN}Deleting objects of type '${_CLR_YELLOW}${TYPE}${_CLR_GREEN}'${_CLR_NC} ..."
  oc get ${TYPE} -n ${TNS} --no-headers 2> /dev/null | awk '{print $1}' | xargs oc delete ${TYPE} -n ${TNS} --wait=false 2> /dev/null
  removeOwnersAndFinalizers ${TNS} ${TYPE}
}

#-------------------------------
deleteCp4baNamespace () {
  TNS=$1
  CR_NAME=$(oc get ICP4ACluster -n ${TNS} --no-headers  2> /dev/null | awk '{print $1}')
  if [[ ! -z "${CR_NAME}" ]]; then
    oc delete ICP4ACluster -n ${TNS} ${CR_NAME} 2> /dev/null
  fi

  CR_NAME=$(oc get Content -n ${TNS} --no-headers  2> /dev/null | awk '{print $1}')
  if [[ ! -z "${CR_NAME}" ]]; then
    oc delete Content -n ${TNS} ${CR_NAME} 2> /dev/null
  fi

  for _type in "${_pakResources[@]}"
  do
    deleteObject ${TNS} ${_type}
  done

  echo "#-----------------------------------------"
  echo -e "${_CLR_GREEN}Deleting namespace '${_CLR_YELLOW}${TNS}${_CLR_GREEN}'${_CLR_NC} ..."
  oc delete ns ${TNS} --wait=false 2> /dev/null
  sleep 5
  
  namespaceExist ${TNS}
  if [ $? -eq 1 ]; then
    _patchLoop=60
    until [ $_patchLoop -lt 1 ];
    do
      ((_patchLoop=_patchLoop-1))
      namespaceExist ${TNS}
      if [ $? -eq 1 ]; then
        oc patch ns ${TNS} --type='merge' -p '{"spec": {"finalizers":null}}' 2> /dev/null 1> /dev/null
        echo -e -n "${_CLR_GREEN}patching finalizers [${_CLR_YELLOW}"${_patchLoop}"${_CLR_GREEN}]${_CLR_NC}  \033[0K\r"
        sleep 1
      else
        echo ""
        break
      fi
    done  
    namespaceExist ${TNS}
    if [ $? -eq 1 ]; then
      deleteCp4baNamespace ${TNS}
    fi
  fi
}

#===========================================================

echo "#========================================="
echo -e "${_CLR_YELLOW}Removing namespace: '${_CLR_GREEN}${_CP4BA_NAMESPACE}${_CLR_YELLOW}'${_CLR_NC}"
namespaceExist ${_CP4BA_NAMESPACE}
if [ $? -eq 1 ]; then
  deleteCp4baNamespace ${_CP4BA_NAMESPACE}
  echo -e "${_CLR_GREEN}Namespace '${_CLR_YELLOW}${_CP4BA_NAMESPACE}${_CLR_GREEN}' removed.${_CLR_NC}"
else
  echo -e "${_CLR_YELLOW}Namespace '${_CLR_GREEN}${_CP4BA_NAMESPACE}${_CLR_YELLOW}' not found.${_CLR_NC}"
fi

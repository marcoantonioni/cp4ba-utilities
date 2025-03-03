#!/bin/bash

_me=$(basename "$0")

_CFG=""

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;32m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

#--------------------------------------------------------
# read command line params
while getopts c:s: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
    esac
done

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file"
  exit 1
fi

source ${_CFG}

#--------------------------------------------------------
resourceExist () {
#    echo "namespace name: $1"
#    echo "resource type: $2"
#    echo "resource name: $3"
  if [ $(oc get $2 -n $1 $3 2> /dev/null | grep $3 | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

#--------------------------------------------------------
_createWxSecret () {

  if [[ ! -z "$1" ]] && [[ ! -z "$2" ]]; then

    resourceExist $1 secret $2
    if [ $? -eq 1 ]; then
      oc delete secret -n $1 $2 2>/dev/null 1>/dev/null
    fi

    _WX_GENAI_TMP="/tmp/cp4ba-wx-genai-$USER-$RANDOM"

    # create payload secret
    echo '<server>' > ${_WX_GENAI_TMP}
    echo '  <authData id="watsonx.ai_auth_alias" user="'${CP4BA_INST_GENAI_WX_USERID}'" password="'${CP4BA_INST_GENAI_WX_APIKEY}'"/>' >> ${_WX_GENAI_TMP}
    echo '</server>' >> ${_WX_GENAI_TMP}

    # create secret for watsonx.ai
    oc create secret generic -n $1 $2 --from-file=sensitiveCustom.xml=${_WX_GENAI_TMP} 2>/dev/null 1>/dev/null

    rm ${_WX_GENAI_TMP} 2>/dev/null 1>/dev/null

  else
    echo -e "${_CLR_RED}[✗] ERROR: _createWxSecret secret name or namespace empty${_CLR_NC}"
    exit 1
  fi
}

#--------------------------------------------------------
_restartServers () {
  if [[ "${CP4BA_INST_TYPE}" = "starter" ]]; then
    BASTUDIO_STATEFULSET=$(oc get statefulsets -n $1 | grep bastudio | awk '{print $1}')
    if [[ ! -z "${BASTUDIO_STATEFULSET}" ]]; then
      NUM_PODS=$(oc get statefulset ${BASTUDIO_STATEFULSET} -n $1 -o jsonpath="{.spec.replicas}")
      echo "Scaling down to zero statefulset "${BASTUDIO_STATEFULSET} 
      oc scale statefulset ${BASTUDIO_STATEFULSET} -n $1 --replicas=0 2>/dev/null 1>/dev/null
      sleep 5
      echo "Scaling up to ${NUM_PODS} statefulset "${BASTUDIO_STATEFULSET} 
      oc scale statefulset ${BASTUDIO_STATEFULSET} -n $1 --replicas=${NUM_PODS} 2>/dev/null 1>/dev/null
    else
      echo -e "${_CLR_YELLOW}WARNING: _restartServers, BAStudio statefulset not found.${_CLR_NC}"
    fi
  else
    echo -e "${_CLR_YELLOW}WARNING: _restartServers not yet implemented for 'production' type deployment.${_CLR_NC}"
  fi
}

#--------------------------------------------------------
_verifyVars() {
  _KO_CFG="false"
  _WRONG_VARS=""
  if [[ -z "${CP4BA_INST_GENAI_WX_USERID}" ]]; then
    export CP4BA_INST_GENAI_WX_USERID="${_WX_USERID}"
    if [[ -z "${CP4BA_INST_GENAI_WX_USERID}" ]]; then
      _KO_CFG="true"
      _WRONG_VARS=${_WRONG_VARS}" CP4BA_INST_GENAI_WX_USERID"
    fi
  fi
  if [[ -z "${CP4BA_INST_GENAI_WX_APIKEY}" ]]; then
    export CP4BA_INST_GENAI_WX_APIKEY="${_WX_APIKEY}"
    if [[ -z "${CP4BA_INST_GENAI_WX_APIKEY}" ]]; then
      _KO_CFG="true"
      _WRONG_VARS=${_WRONG_VARS}" CP4BA_INST_GENAI_WX_APIKEY"
    fi
  fi
  if [[ "${_KO_CFG}" = "true" ]]; then
    echo -e "${_CLR_RED}[✗] ERROR: _verifyVars GenAI configuration error, verify values for:${_CLR_YELLOW}${_WRONG_VARS}${_CLR_NC}"
    return 0
  fi
  return 1
}

#-------------------------------
namespaceExist () {
# ns name: $1
  if [ $(oc get ns $1 2>/dev/null | grep $1 2>/dev/null | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

#--------------------------------------------------------
configureGenAISecret() {
  _verifyVars
  if [ $? -eq 1 ]; then
    namespaceExist $1
    if [ $? -eq 1 ]; then
      _createWxSecret $1 ${CP4BA_INST_GENAI_WX_AUTH_SECRET}
      _restartServers $1
    else
      echo -e "${_CLR_RED}[✗] Error, namespace '${_CLR_YELLOW}$1${_CLR_RED}' doesn't exists. ${_CLR_NC}"
      exit 1
    fi
  fi
}

#==================================

echo -e "=============================================================="
echo -e "${_CLR_GREEN}Configuring GenAI Secret '${_CLR_YELLOW}${CP4BA_INST_NAMESPACE}${_CLR_GREEN}' namespace${_CLR_NC}"

configureGenAISecret ${CP4BA_INST_NAMESPACE}

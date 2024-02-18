#!/bin/bash

_CLR_OFF="\033[0m"     # Color off
_CLR_BLNK="\033[5m"    # Blink
_CLR_BLU="\033[0;34m"  # Blue
_CLR_CYN="\033[0;36m"  # Cyan
_CLR_GRN="\033[0;32m"  # Green
_CLR_PPL="\033[0;35m"  # Purple
_CLR_RED="\033[0;31m"  # Red
_CLR_WHT="\033[0;37m"  # White
_CLR_YLW="\033[0;33m"  # Yellow
_CLR_BBLU="\033[1;34m" # Bold Blue
_CLR_BCYN="\033[1;36m" # Bold Cyan
_CLR_BGRN="\033[1;32m" # Bold Green
_CLR_BPPL="\033[1;35m" # Bold Purple
_CLR_BRED="\033[1;31m" # Bold Red
_CLR_BWHT="\033[1;37m" # Bold White
_CLR_BYLW="\033[1;33m" # Bold Yellow

_ECHO=0
_TARGET_NAMESPACE=""
_TARGET_ZEN_SERVICE_NAME=""
_TARGET_NEW_SECRET_NAME=""
_SOURCE_SECRET_NAME=""
_SOURCE_SECRET_NAMESPACE=""

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -n target-namespace
    -z target-zenservice-name
    -s target-new-secret-name 
    -f source-secret-name
    -k source-secret-namespace
    -w wait-progress
    ${_CLR_NC}"
}

_OK_PARAMS=0
_SOURCE_SECRET=0
_EXIST_SOURCE_SECRET=0
_EXIST_TARGET_SECRET=0
_EXIST_TARGET_ZEN_SERVICE=0
_WAIT_PROGRESS=false

#--------------------------------------------------------
# read command line params
while getopts n:z:s:f:k:w flag
do
    case "${flag}" in
        n) _TARGET_NAMESPACE=${OPTARG};;
        z) _TARGET_ZEN_SERVICE_NAME=${OPTARG};;
        s) _TARGET_NEW_SECRET_NAME=${OPTARG};;
        f) _SOURCE_SECRET_NAME=${OPTARG};;
        k) _SOURCE_SECRET_NAMESPACE=${OPTARG};;
        w) _WAIT_PROGRESS=true;;
    esac
done

#-------------------------------
resourceExist () {
#    namespace name: $1
#    resource type: $2
#    resource name: $3
  if [ $(oc get $2 -n $1 $3 2> /dev/null | grep $3 | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

#-------------------------------
verifyMandatoryParams() {
  if [[ "${_WAIT_PROGRESS}" = "true" ]]; then
    _TARGET_NEW_SECRET_NAME="n-a"
  fi
  if [[ ! -z "${_TARGET_NAMESPACE}" ]] && [[ ! -z "${_TARGET_ZEN_SERVICE_NAME}" ]] && [[ ! -z "${_TARGET_NEW_SECRET_NAME}" ]]; then
    _OK_PARAMS=1
  fi

  [[ $_ECHO -gt 0 ]] && echo "-> verifyMandatoryParams ${_OK_PARAMS}"
}

#-------------------------------
verifySourceSecret() {
  if [[ ! -z "${_SOURCE_SECRET_NAME}" ]] || [[ ! -z "${_SOURCE_SECRET_NAMESPACE}" ]]; then
    if [[ ! -z "${_SOURCE_SECRET_NAME}" ]] && [[ ! -z "${_SOURCE_SECRET_NAMESPACE}" ]]; then
      _SOURCE_SECRET=1
    fi
  fi

  [[ $_ECHO -gt 0 ]] && echo "-> verifySourceSecret ${_SOURCE_SECRET}"
}

#-------------------------------
existSourceSecret() {
  resourceExist "${_SOURCE_SECRET_NAMESPACE}" "secret" "${_SOURCE_SECRET_NAME}"
  _EXIST_SOURCE_SECRET=$?

  [[ $_ECHO -gt 0 ]] && echo "-> existSourceSecret ${_EXIST_SOURCE_SECRET}"
}

#-------------------------------
existTargetSecret() {
  resourceExist "${_TARGET_NAMESPACE}" "secret" "${_TARGET_NEW_SECRET_NAME}"
  _EXIST_TARGET_SECRET=$?

  [[ $_ECHO -gt 0 ]] && echo "-> existTargetSecret ${_EXIST_TARGET_SECRET}"
}

#-------------------------------
existTargetZenService() {
  resourceExist "${_TARGET_NAMESPACE}" "zenservice" "${_TARGET_ZEN_SERVICE_NAME}"
  _EXIST_TARGET_ZEN_SERVICE=$?

  [[ $_ECHO -gt 0 ]] && echo "-> existTargetZenService ${_EXIST_TARGET_ZEN_SERVICE}"
}

#-------------------------------
cloneSecretToTarget() {
  [[ $_ECHO -gt 0 ]] && echo "-> cloneSecretToTarget"

  oc get secret -n ${_SOURCE_SECRET_NAMESPACE} ${_SOURCE_SECRET_NAME} -o jsonpath='{.data.tls\.crt}' | base64 -d | awk 'split_after==1{n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1} {if(length($0) > 0) print > "/tmp/cp4ba-ep-cert" n ".pem"}'

  oc get secret -n ${_SOURCE_SECRET_NAMESPACE} ${_SOURCE_SECRET_NAME} -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/cp4ba-ep-cert-tls.key

  oc get route -n ${_TARGET_NAMESPACE} cpd -o jsonpath='{.spec.tls.destinationCACertificate}' > /tmp/cp4ba-ep-dest.crt
  mv /tmp/cp4ba-ep-cert1.pem /tmp/cp4ba-ep-cert-ca.crt
  mv /tmp/cp4ba-ep-cert.pem /tmp/cp4ba-ep-cert-tls.crt

  existTargetSecret
  if [[ $_EXIST_TARGET_SECRET -eq 1 ]]; then
    oc delete secret -n ${_TARGET_NAMESPACE} ${_TARGET_NEW_SECRET_NAME} 2>/dev/null
  fi

  oc -n ${_TARGET_NAMESPACE} create secret generic ${_TARGET_NEW_SECRET_NAME} \
    --from-file=tls.crt=/tmp/cp4ba-ep-cert-tls.crt \
    --from-file=tls.key=/tmp/cp4ba-ep-cert-tls.key \
    --from-file=ca.crt=/tmp/cp4ba-ep-cert-ca.crt \
    --dry-run=client -o yaml | oc apply -f -

  rm /tmp/cp4ba-ep-cert-ca.crt
  rm /tmp/cp4ba-ep-cert-tls.crt
  rm /tmp/cp4ba-ep-cert-tls.key
  rm /tmp/cp4ba-ep-dest.crt
}

applySecretToZenService() {
  [[ $_ECHO -gt 0 ]] && echo "-> applySecretToZenService"

  existTargetZenService
  if [[ $_EXIST_TARGET_ZEN_SERVICE -eq 1 ]]; then
    _ROUTE_HOST=$(oc get -n ${_TARGET_NAMESPACE} zenservice ${_TARGET_ZEN_SERVICE_NAME} -o jsonpath='{.spec.zenCustomRoute.route_host}')
    _OLD_SECRET=$(oc get -n ${_TARGET_NAMESPACE} zenservice ${_TARGET_ZEN_SERVICE_NAME} -o jsonpath='{.spec.zenCustomRoute.route_secret}')

    oc patch ZenService -n ${_TARGET_NAMESPACE} ${_TARGET_ZEN_SERVICE_NAME} --type='json' -p='[{"op": "add", "path": "/spec/zenCustomRoute","value":{"route_host":"'${_ROUTE_HOST}'","route_secret":"'${_TARGET_NEW_SECRET_NAME}'","route_reencrypt":true}}]'

    echo "Route host '${_ROUTE_HOST}' updated with new secret '${_TARGET_NEW_SECRET_NAME}', old secret '${_OLD_SECRET}'"
  else
    echo "ERROR, zenservice '${_TARGET_ZEN_SERVICE_NAME}' not found in namespace '${_TARGET_NAMESPACE}'"
    exit 1
  fi
}

waitForProgress() {
  while [ true ]
  do
    _PROGRESS=$(oc get zenservice -n ${_TARGET_NAMESPACE} ${_TARGET_ZEN_SERVICE_NAME} -o jsonpath='{.status.Progress}')
    if [[ ${_PROGRESS} = "100%" ]]; then
      echo ""
      echo "Progress completed"
      break
    else
      echo -e -n "${_CLR_GREEN}Progress '${_CLR_YELLOW}${_PROGRESS}${_CLR_GREEN}' ${_CLR_NC}\033[0K\r"
      sleep 5
    fi
  done
}

#=================================

verifyMandatoryParams
if [[ $_OK_PARAMS -eq 0 ]]; then
  usage
  exit 1
fi

if [[ "${_WAIT_PROGRESS}" = "true" ]]; then
  echo "Wait for ZenService update completion" 
  waitForProgress
else
  echo "Apply certificate to ZenService" 
  verifySourceSecret
  if [[ $_SOURCE_SECRET -eq 1 ]]; then
    existSourceSecret
    if [[ $_EXIST_SOURCE_SECRET -eq 1 ]]; then
      cloneSecretToTarget
    else
      echo "ERROR, source secret '${_SOURCE_SECRET_NAME}' not found in namespace '${_SOURCE_SECRET_NAMESPACE}'"
      exit 1
    fi
  fi

  existTargetSecret
  if [[ $_EXIST_TARGET_SECRET -eq 1  ]]; then
    applySecretToZenService
  fi
fi

echo "Done"
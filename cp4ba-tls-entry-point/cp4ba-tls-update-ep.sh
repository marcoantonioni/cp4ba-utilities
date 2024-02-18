#!/bin/bash

_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;32m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

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
    -x no-wait-after-update
    -w wait-progress
    ${_CLR_NC}"
}

_OK_PARAMS=0
_SOURCE_SECRET=0
_EXIST_SOURCE_SECRET=0
_EXIST_TARGET_SECRET=0
_EXIST_TARGET_ZEN_SERVICE=0
_WAIT_PROGRESS=false
_NO_WAIT_PROGRESS=false

#--------------------------------------------------------
# read command line params
while getopts n:z:s:f:k:wx flag
do
    case "${flag}" in
        n) _TARGET_NAMESPACE=${OPTARG};;
        z) _TARGET_ZEN_SERVICE_NAME=${OPTARG};;
        s) _TARGET_NEW_SECRET_NAME=${OPTARG};;
        f) _SOURCE_SECRET_NAME=${OPTARG};;
        k) _SOURCE_SECRET_NAMESPACE=${OPTARG};;
        w) _WAIT_PROGRESS=true;;
        x) _NO_WAIT_PROGRESS=true;;
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
    oc delete secret -n ${_TARGET_NAMESPACE} ${_TARGET_NEW_SECRET_NAME} 2>/dev/null 1>/dev/null
  fi

  oc -n ${_TARGET_NAMESPACE} create secret generic ${_TARGET_NEW_SECRET_NAME} \
    --from-file=tls.crt=/tmp/cp4ba-ep-cert-tls.crt \
    --from-file=tls.key=/tmp/cp4ba-ep-cert-tls.key \
    --from-file=ca.crt=/tmp/cp4ba-ep-cert-ca.crt \
    --dry-run=client -o yaml | oc apply -f - 2>/dev/null 1>/dev/null

  rm /tmp/cp4ba-ep-cert-ca.crt 2>/dev/null
  rm /tmp/cp4ba-ep-cert-tls.crt 2>/dev/null
  rm /tmp/cp4ba-ep-cert-tls.key 2>/dev/null
  rm /tmp/cp4ba-ep-dest.crt 2>/dev/null
}

applySecretToZenService() {
  [[ $_ECHO -gt 0 ]] && echo "-> applySecretToZenService"

  existTargetZenService
  if [[ $_EXIST_TARGET_ZEN_SERVICE -eq 1 ]]; then
    _ROUTE_HOST=$(oc get -n ${_TARGET_NAMESPACE} zenservice ${_TARGET_ZEN_SERVICE_NAME} -o jsonpath='{.spec.zenCustomRoute.route_host}')
    _OLD_SECRET=$(oc get -n ${_TARGET_NAMESPACE} zenservice ${_TARGET_ZEN_SERVICE_NAME} -o jsonpath='{.spec.zenCustomRoute.route_secret}')

    oc patch ZenService -n ${_TARGET_NAMESPACE} ${_TARGET_ZEN_SERVICE_NAME} --type='json' -p='[{"op": "add", "path": "/spec/zenCustomRoute","value":{"route_host":"'${_ROUTE_HOST}'","route_secret":"'${_TARGET_NEW_SECRET_NAME}'","route_reencrypt":true}}]'

    echo "${_CLR_GREEN}Route host '${_CLR_YELLOW}${_ROUTE_HOST}${_CLR_GREEN}' updated with new secret '${_CLR_YELLOW}${_TARGET_NEW_SECRET_NAME}${_CLR_GREEN}', old secret '${_CLR_YELLOW}${_OLD_SECRET}${_CLR_GREEN}'${_CLR_NC}"
  else
    echo "${_CLR_RED}ERROR, zenservice '${_CLR_YELLOW}${_TARGET_ZEN_SERVICE_NAME}${_CLR_RED}' not found in namespace '${_CLR_YELLOW}${_TARGET_NAMESPACE}${_CLR_RED}'${_CLR_NC}"
    exit 1
  fi
}

waitForProgress() {
  _ENTRY=1
  while [ true ]
  do
    _PROGRESS=$(oc get zenservice -n ${_TARGET_NAMESPACE} ${_TARGET_ZEN_SERVICE_NAME} -o jsonpath='{.status.Progress}')
    if [[ ${_PROGRESS} = "100%" ]] && [[ $_ENTRY -eq 1 ]]; then
      _PROGRESS="0%"
      echo -e -n "${_CLR_GREEN}Wait operator${_CLR_NC}\033[0K\r"
      sleep 5
      echo -e -n "              \033[0K\r"
    else
      if [[ ${_PROGRESS} = "100%" ]]; then
        echo "${_CLR_GREEN}Progress completed${_CLR_NC}"
        break
      else
        _ENTRY=0
        echo -e -n "${_CLR_GREEN}Progress '${_CLR_YELLOW}${_PROGRESS}${_CLR_GREEN}' ${_CLR_NC}\033[0K\r"
        sleep 5
      fi
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
  echo -e "${_CLR_GREEN}Wait for ZenService update completion${_CLR_NC}" 
  waitForProgress
else
  echo -e "${_CLR_GREEN}Apply certificate to ZenService${_CLR_NC}" 
  verifySourceSecret
  if [[ $_SOURCE_SECRET -eq 1 ]]; then
    existSourceSecret
    if [[ $_EXIST_SOURCE_SECRET -eq 1 ]]; then
      cloneSecretToTarget
    else
      echo "${_CLR_RED}ERROR, source secret '${_CLR_YELLOW}${_SOURCE_SECRET_NAME}${_CLR_RED}' not found in namespace '${_CLR_YELLOW}${_SOURCE_SECRET_NAMESPACE}${_CLR_RED}'${_CLR_NC}"
      exit 1
    fi
  fi

  existTargetSecret
  if [[ $_EXIST_TARGET_SECRET -eq 1  ]]; then
    applySecretToZenService
    if [[ $_NO_WAIT_PROGRESS -eq 0 ]]; then
      waitForProgress
    fi
  fi
fi

echo "Done"
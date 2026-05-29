#!/bin/bash

#set -euo pipefail


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

_BAW_DEPL_NAMESPACE=""
_BAW_DEPL_NAME=""
_CR_NAME=""
_BAW_ADMINUSER=""
_BAW_ADMINPASSWORD=""

_BAW_APP=""
_BAW_APP_BRANCH=""
_BAW_APP_STATE="activate"
_BAW_APP_DEFAULT=false
_BAW_APP_FORCE=false
_BAW_APP_SUSPEND_INSTANCES=false

#----------------------------------------------------
_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

#----------------------------------------------------
if [[ ! -f "$_SCRIPT_DIR/../../cp4ba-logger/scripts/logger.sh" ]]; then
  echo "Error, log package not found !"
  echo "Clone it alongside with other cp4ba-..."
  echo "use the command: git clone https://github.com/marcoantonioni/cp4ba-logger"
  exit 1
fi
source $_SCRIPT_DIR/../../cp4ba-logger/scripts/logger.sh
if [[ -z "${CP4BA_LOGGING_ENABLED}" ]]; then 
  export CP4BA_LOGGING_ENABLED=true
fi
if [[ -z "${CP4BA_LOG_LEVEL}" ]]; then 
  export CP4BA_LOG_LEVEL="INFO"
fi
if [[ -z "${CP4BA_LOG_TO_CONSOLE}" ]]; then 
  export CP4BA_LOG_TO_CONSOLE=true
fi
if [[ -z "${CP4BA_LOG_TO_FILE}" ]]; then 
  export CP4BA_LOG_TO_FILE=false
fi
if [[ -z "${CP4BA_LOG_FILE}" ]]; then 
  export CP4BA_LOG_FILE=""
fi
if [[ -z "${CP4BA_LOG_MAX_SIZE}" ]]; then 
  export CP4BA_LOG_MAX_SIZE=$((10 * 1024 * 1024))
fi
if [[ -z "${CP4BA_LOG_BACKUP_COUNT}" ]]; then 
  export CP4BA_LOG_BACKUP_COUNT=5
fi

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -n namespace
    -b baw-name
    -c cr-name 
    -u admin-user
    -p password
    -a app-acronym
    -v snapshot-name
    -o [activate | deactivate]
    -m make-default
    -s suspend-instances
    -f force-deactivation${_CLR_NC}"
}


#--------------------------------------------------------
# read command line params
while getopts n:b:c:u:p:a:v:o:mfs flag
do
    case "${flag}" in
        n) _BAW_DEPL_NAMESPACE=${OPTARG};;
        b) _BAW_DEPL_NAME=${OPTARG};;
        c) _CR_NAME=${OPTARG};;
        u) _BAW_ADMINUSER=${OPTARG};;
        p) _BAW_ADMINPASSWORD=${OPTARG};;
        a) _BAW_APP=${OPTARG};;
        v) _BAW_APP_BRANCH=${OPTARG};;
        o) _BAW_APP_STATE=${OPTARG};;
        m) _BAW_APP_DEFAULT=true;;
        s) _BAW_APP_SUSPEND_INSTANCES=true;;
        f) _BAW_APP_FORCE=true;;        
    esac
done

updateApplication () {

  log_msg "Update application: ${_BAW_APP_BRANCH} - ${_BAW_APP}"
  _BAW_EXTERNAL_BASE_URL=$(oc get ICP4ACluster -n ${_BAW_DEPL_NAMESPACE} ${_CR_NAME} -o jsonpath='{.status.endpoints}' | jq '.[] | select(.scope == "External") | select(.name | contains("base URL for '${_BAW_DEPL_NAME}'"))' | jq .uri | sed 's/"//g')

  LOGIN_URI="${_BAW_EXTERNAL_BASE_URL}ops/system/login"

  log_msg "Wait for CSRF token, login to ${LOGIN_URI}"
  until _CSRF_TOKEN=$(curl -ks -u ${_BAW_ADMINUSER}:${_BAW_ADMINPASSWORD} -X POST -H 'accept: application/json' -H 'Content-Type: application/json' ${LOGIN_URI} -d '{"refresh_groups": true, "requested_lifetime": 7200}' | jq .csrf_token 2>/dev/null | sed 's/"//g') && [[ -n "$_CSRF_TOKEN" ]]
  do
    #echo -n "."
    sleep 1
  done

  log_msg ""
  log_msg "Working on application acronym ["${_BAW_APP}"] branch ["${_BAW_APP_BRANCH}"]... "

  _CMD="ops/std/bpm/containers/${_BAW_APP}/versions/${_BAW_APP_BRANCH}/${_BAW_APP_STATE}?force=${_BAW_APP_FORCE}&suspend_bpd_instances=${_BAW_APP_SUSPEND_INSTANCES}"
  _RESPONSE=$(curl -sk -u ${_BAW_ADMINUSER}:${_BAW_ADMINPASSWORD} -H 'accept: application/json' -H 'BPMCSRFToken: '${_CSRF_TOKEN} -X POST "${_BAW_EXTERNAL_BASE_URL}${_CMD}")  

  if [[ "${_RESPONSE}" == *"error_"* ]]; then
    log_msg ""
    log_error "ERROR configuring '${_BAW_APP}/${_BAW_APP_BRANCH}' details:"
    echo "${_RESPONSE}" | jq .
    log_msg
    exit 1
  fi

  if [[ "${_BAW_APP_STATE}" = "activate" ]]; then
    if [[ "${_BAW_APP_DEFAULT}" = "true" ]]; then    
      _URI="/std/bpm/containers/${_BAW_APP}/versions/${_BAW_APP_BRANCH}/make_default"
      _RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${_CSRF_TOKEN} -X POST ${_BAW_EXTERNAL_BASE_URL}/${_URI})
      if [[ "${_RESPONSE}" == *"error_"* ]]; then
        log_msg ""
        log_error "ERROR making default '${_BAW_APP}/${_BAW_APP_BRANCH}' details:"
        echo "${_RESPONSE}" | jq .
        log_msg
        exit 1
      fi
    fi
  fi
  log_msg "Configured !"

}

if [[ -z "${_BAW_DEPL_NAMESPACE}" ]] || [[ -z "${_BAW_DEPL_NAME}" ]] || [[ -z "${_CR_NAME}" ]] || [[ -z "${_BAW_ADMINUSER}" ]] || [[ -z "${_BAW_ADMINPASSWORD}" ]] || [[ -z "${_BAW_APP}" ]] || [[ -z "${_BAW_APP_BRANCH}" ]]; then
  log_error "ERROR: Empty values for required parameter"
  usage
  exit 1
fi

if [[ "${_BAW_APP_STATE}" = "activate" ]] || [[ "${_BAW_APP_STATE}" = "deactivate" ]]; then
  updateApplication
else
  log_error "ERROR: invalid operation: ${_BAW_APP_STATE}"
  usage
  exit 1
fi
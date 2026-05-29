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

_BAS_EXTERNAL_BASE_URL=""
_BAS_APP_NAME=""
_BAS_APP_ACRONYM=""
_BAS_ADMINUSER=""
_BAS_ADMINPASSWORD=""
_FILE_OUT=""

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

#--------------------------------------------------------
_INST_TMP_FOLDER="/tmp"
setTemporaryFolder () {
  _OK=0
  _ERR_MSG_FOLDER="is a folder"
  _ERR_MSG_PERMISSIONS=""
  if [[ ! -z "${CP4BA_INST_TMP_FOLDER}" ]]; then
    if [[ -d "${CP4BA_INST_TMP_FOLDER}" ]]; then
      if [[ -r "${CP4BA_INST_TMP_FOLDER}" ]] && [[ -w "${CP4BA_INST_TMP_FOLDER}" ]]; then 
        _OK=1
      else
        _ERR_MSG_PERMISSIONS=", you have not rights to read and/or write"
        _OK=-1
      fi
    else
      _ERR_MSG_FOLDER="is NOT a folder"
    fi

    if [[ $_OK -lt 1 ]]; then
      log_error "${_CLR_RED}[✗] ERROR '${_CLR_YELLOW}${CP4BA_INST_TMP_FOLDER}${_CLR_RED}' is not a valid temporary folder, check if it is a folder or if you have write permissions !${_CLR_NC}"
      log_error "${_CLR_RED}'${_CLR_YELLOW}${CP4BA_INST_TMP_FOLDER}${_CLR_RED}' ${_ERR_MSG_FOLDER}${_ERR_MSG_PERMISSIONS}${_CLR_NC}"
      exit 1
    fi
    export _INST_TMP_FOLDER="${CP4BA_INST_TMP_FOLDER}"
  fi
  log_info "${_CLR_GREEN}Running with temporary folder '${_CLR_YELLOW}${_INST_TMP_FOLDER}${_CLR_GREEN}'${_CLR_NC}"

}

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -s studio-url (https://hostname/bas)
    -n app-name
    -a app-acronym 
    -u admin-user
    -p password
    -f app-file${_CLR_NC}"
}


#--------------------------------------------------------
# read command line params
while getopts s:n:a:u:p:f: flag
do
    case "${flag}" in
        s) _BAS_EXTERNAL_BASE_URL=${OPTARG};;
        n) _BAS_APP_NAME=${OPTARG};;
        a) _BAS_APP_ACRONYM=${OPTARG};;
        u) _BAS_ADMINUSER=${OPTARG};;
        p) _BAS_ADMINPASSWORD=${OPTARG};;
        f) _FILE_OUT=${OPTARG};;
    esac
done

exportApplication () {

  log_info "Exporting application file: ${_FILE_OUT}"
  LOGIN_URI="${_BAS_EXTERNAL_BASE_URL}/ops/system/login"

  log_info "Wait for CSRF token, login to ${LOGIN_URI}"
  until _CSRF_TOKEN=$(curl -ks -u ${_BAS_ADMINUSER}:${_BAS_ADMINPASSWORD} -X POST -H 'accept: application/json' -H 'Content-Type: application/json' ${LOGIN_URI} -d '{"refresh_groups": true, "requested_lifetime": 7200}' | jq .csrf_token 2>/dev/null | sed 's/"//g') && [[ -n "$_CSRF_TOKEN" ]]
  do
    #echo -n "."
    sleep 1
  done
  #echo ""
  _BASIC_AUTH=$(echo "${_BAS_ADMINUSER}:${_BAS_ADMINPASSWORD}" | base64) 

  _TMP_FILE="${_INST_TMP_FOLDER}/cp4ba-exp-file-$USER-$RANDOM" 

  curl -sk -C - -H 'Authorization: Basic '${_BASIC_AUTH} \
    -o ${_TMP_FILE} \
    -H 'accept: application/octet-stream' \
    -H 'BPMCSRFToken: '${_CSRF_TOKEN} \
    -X GET "${_BAS_EXTERNAL_BASE_URL}/ops/std/bpm/containers/"${_BAS_APP_NAME}"/versions/"${_BAS_APP_ACRONYM}"/install_package?use_enhanced_filenames=false"

  _KO=1
  if [[ -f "${_TMP_FILE}" ]]; then
    _IS_ERR=$(xxd -l 100 ${_TMP_FILE} | grep "error_message" | wc -l)
    if [[ $_IS_ERR -eq 0 ]]; then
      rm ${_FILE_OUT} 2>/dev/null
      mv ${_TMP_FILE} ${_FILE_OUT} # 2>/dev/null
      if [[ $? -eq 0 ]]; then
        log_info "Application successfully exported in file ${_FILE_OUT}"
        _KO=0
      fi
    fi
  fi
  if [[ $_KO -eq 1 ]]; then
    log_error "ERROR exporting application."
  fi
}

if [[ -z "${_BAS_EXTERNAL_BASE_URL}" ]] || [[ -z "${_BAS_APP_ACRONYM}" ]] || [[ -z "${_BAS_APP_NAME}" ]] || 
   [[ -z "${_BAS_ADMINUSER}" ]] || [[ -z "${_BAS_ADMINPASSWORD}" ]] || [[ -z "${_FILE_OUT}" ]]; then
  log_error "ERROR: Empty values for required parameter"
  usage
  exit 1
fi

setTemporaryFolder

exportApplication
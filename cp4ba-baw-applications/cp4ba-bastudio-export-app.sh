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

_BAS_EXTERNAL_BASE_URL=""
_BAS_APP_NAME=""
_BAS_APP_ACRONYM=""
_BAS_ADMINUSER=""
_BAS_ADMINPASSWORD=""
_FILE_OUT=""

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

  echo "Exporting application file: ${_FILE_OUT}"
  LOGIN_URI="${_BAS_EXTERNAL_BASE_URL}/ops/system/login"

  echo "Wait for CSRF token, login to ${LOGIN_URI}"
  until _CSRF_TOKEN=$(curl -ks -u ${_BAS_ADMINUSER}:${_BAS_ADMINPASSWORD} -X POST -H 'accept: application/json' -H 'Content-Type: application/json' ${LOGIN_URI} -d '{"refresh_groups": true, "requested_lifetime": 7200}' | jq .csrf_token 2>/dev/null | sed 's/"//g') && [[ -n "$_CSRF_TOKEN" ]]
  do
    echo -n "."
    sleep 1
  done
  echo ""
  _BASIC_AUTH=$(echo "${_BAS_ADMINUSER}:${_BAS_ADMINPASSWORD}" | base64) 

  _TMP_FILE="/tmp/cp4ba-exp-file-$USER-$RANDOM" 
  
  curl -sk -H 'authorization: Basic '${_BASIC_AUTH} \
    -o ${_TMP_FILE} \
    -H 'accept: application/octet-stream' -H 'BPMCSRFToken: '${_CSRF_TOKEN} \
    -X GET "${_BAS_EXTERNAL_BASE_URL}/ops/std/bpm/containers/"${_BAS_APP_NAME}"/versions/"${_BAS_APP_ACRONYM}"/install_package"
  _KO=1
  if [[ -f "${_TMP_FILE}" ]]; then

    _IS_ERR=$(xxd -l 100 ${_TMP_FILE} | grep "error_message" | wc -l)
    if [[ $_IS_ERR -eq 0 ]]; then
      rm ${_FILE_OUT} 2>/dev/null
      mv ${_TMP_FILE} ${_FILE_OUT} 2>/dev/null
      if [[ $? -eq 0 ]]; then
        echo "Application successfully exported in file ${_FILE_OUT}"
        _KO=0
      fi
    fi
  fi
  if [[ $_KO -eq 1 ]]; then
    echo "ERROR exporting application."
  fi
  rm ${_TMP_FILE} 2>/dev/null
}

if [[ -z "${_BAS_EXTERNAL_BASE_URL}" ]] || [[ -z "${_BAS_APP_ACRONYM}" ]] || [[ -z "${_BAS_APP_NAME}" ]] || 
   [[ -z "${_BAS_ADMINUSER}" ]] || [[ -z "${_BAS_ADMINPASSWORD}" ]] || [[ -z "${_FILE_OUT}" ]]; then
  echo "ERROR: Empty values for required parameter"
  usage
  exit 1
fi

exportApplication
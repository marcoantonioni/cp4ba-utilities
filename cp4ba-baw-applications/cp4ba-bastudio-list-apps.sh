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
_DETAILS=false

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -s studio-url (https://hostname/bas)
    -u admin-user
    -p password
    -n app-name
    -a app-acronym 
    -d details${_CLR_NC}"
}


#--------------------------------------------------------
# read command line params
while getopts s:n:a:u:p:d flag
do
    case "${flag}" in
        s) _BAS_EXTERNAL_BASE_URL=${OPTARG};;
        n) _BAS_APP_NAME=${OPTARG};;
        a) _BAS_APP_ACRONYM=${OPTARG};;
        u) _BAS_ADMINUSER=${OPTARG};;
        p) _BAS_ADMINPASSWORD=${OPTARG};;
        d) _DETAILS=true;;
    esac
done

listApplications () {

  echo "List applications"
  LOGIN_URI="${_BAS_EXTERNAL_BASE_URL}/ops/system/login"

  echo "Wait for CSRF token, login to ${LOGIN_URI}"
  until _CSRF_TOKEN=$(curl -ks -u ${_BAS_ADMINUSER}:${_BAS_ADMINPASSWORD} -X POST -H 'accept: application/json' -H 'Content-Type: application/json' ${LOGIN_URI} -d '{"refresh_groups": true, "requested_lifetime": 7200}' | jq .csrf_token 2>/dev/null | sed 's/"//g') && [[ -n "$_CSRF_TOKEN" ]]
  do
    echo -n "."
    sleep 1
  done
  echo ""
  _BASIC_AUTH=$(echo "${_BAS_ADMINUSER}:${_BAS_ADMINPASSWORD}" | base64) 


  if [[ ! -z "${_BAS_APP_NAME}" ]]; then

    _APPS=$(curl -sk -H 'authorization: Basic '${_BASIC_AUTH} \
              -o ${_TMP_FILE} \
              -H 'accept: application/octet-stream' -H 'BPMCSRFToken: '${_CSRF_TOKEN} \
              -X GET "${_BAS_EXTERNAL_BASE_URL}/ops/std/bpm/containers/"${_BAS_APP_NAME}"/versions")
    
    if [[ "${_DETAILS}" = "true" ]]; then
      echo ${_APPS} | jq .[]
    else
      echo "Acronym - Name - Installable - Snapshot - Description"
      echo "---------------------------------------"

      for row in $(echo "${_APPS}" | jq -r '.versions[] | @base64'); do
          _jq() {
            
            _APP_NAME=$(echo ${row} | base64 --decode | jq -r ".container_name")
            _APP_CTR=$(echo ${row} | base64 --decode | jq -r ".container")
            _APP_VER=$(echo ${row} | base64 --decode | jq -r ".version")
            _APP_DES=$(echo ${row} | base64 --decode | jq -r ".version_name")
            _INSTALLABLE=$(echo ${row} | base64 --decode | jq -r ".installable")

            echo "${_APP_CTR} - ${_APP_VER} - ${_INSTALLABLE} - ${_APP_NAME} - ${_APP_DES}" | sed 's/"//g'
          }
        echo $(_jq '.version')
      done
    fi  
  else

    _APPS=$(curl -sk -X 'GET' ${_BAS_EXTERNAL_BASE_URL}"/ops/std/bpm/containers?type=PA&optional_parts=versions" \
              -H 'accept: application/json' \
              -H 'BPMCSRFToken: '${_CSRF_TOKEN} \
              -H 'authorization: Basic '${_BASIC_AUTH})

      echo "Acronym - Name"
      echo "--------------"

      for row in $(echo "${_APPS}" | jq -r '.containers[] | @base64'); do
          _jq() {
            
            _APP_NAME=$(echo ${row} | base64 --decode | jq -r ".container_name")
            _APP_CTR=$(echo ${row} | base64 --decode | jq -r ".container")

            echo "${_APP_CTR} - ${_APP_NAME}" | sed 's/"//g'
          }
        echo $(_jq 'container')
      done
  fi

}

if [[ -z "${_BAS_EXTERNAL_BASE_URL}" ]] || [[ -z "${_BAS_ADMINUSER}" ]] || [[ -z "${_BAS_ADMINPASSWORD}" ]]; then
  echo "ERROR: Empty values for required parameter"
  usage
  exit 1
fi

listApplications

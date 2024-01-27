#!/bin/bash

_me=$(basename "$0")

_BAW_DEPL_NAMESPACE=""
_BAW_DEPL_NAME=""
_CR_NAME=""
_BAW_APP=""
_BAW_APP_BRANCH=""
_BAW_ADMINUSER=""
_BAW_ADMINPASSWORD=""
_TEAM_BINDINGS_FILE=""
_BAW_CSRF_TOKEN=""
_REMOVE=false
_BAW_EXTERNAL_BASE_URL=""

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
    -t team-bindings-file
    -r remove-contents-before-apply${_CLR_NC}"
}

#--------------------------------------------------------
# read command line params
while getopts n:b:c:u:p:a:v:t:r flag
do
    case "${flag}" in
        n) _BAW_DEPL_NAMESPACE=${OPTARG};;
        b) _BAW_DEPL_NAME=${OPTARG};;
        c) _CR_NAME=${OPTARG};;
        u) _BAW_ADMINUSER=${OPTARG};;
        p) _BAW_ADMINPASSWORD=${OPTARG};;
        a) _BAW_APP=${OPTARG};;
        v) _BAW_APP_BRANCH=${OPTARG};;
        t) _TEAM_BINDINGS_FILE=${OPTARG};;
        r) _REMOVE=true
    esac
done


#--------------------------------------------------------------
# update team binding
updateTB () {

  TB_WHAT=$1
  TB_NAME=$2
  TB_CONTENT=$3
  _CONTENT_TO_SET=""

  if [[ "${TB_WHAT}" != "add_manager" ]]; then
    if [[ ! -z "${TB_CONTENT}" ]]; then
      IFS=$','
      read -a ITEMS <<< "${TB_CONTENT}"
      unset IFS

      UPDATED_LIST=""
      max_len=${#ITEMS[*]}
      idx=0
      for ITEM in "${ITEMS[@]}";
      do
        FORMATTED_ITEM="\""${ITEM}"\""
        UPDATED_LIST=${UPDATED_LIST}${FORMATTED_ITEM}
        idx=$((idx+1))
        if [[ $idx < $max_len ]]; then
          UPDATED_LIST=${UPDATED_LIST}","
        fi
      done
      _CONTENT_TO_SET=${UPDATED_LIST}
    fi
  else
    _CONTENT_TO_SET="\""${TB_CONTENT}"\""
  fi

  if [[ ! -z "${_CONTENT_TO_SET}" ]]; then
    echo -n "Updating team binding '${TB_NAME}' for '${TB_WHAT}' operation ..."
    _URI="ops/std/bpm/containers/${_BAW_APP}/versions/${_BAW_APP_BRANCH}/team_bindings/${TB_NAME}"

    if [[ "${TB_WHAT}" = "add_manager" ]]; then
      # single item
      _DATA='{"'${TB_WHAT}'": '${_CONTENT_TO_SET}',"set_auto_refresh_enabled": true}'
    else
      # list of items
      _DATA='{"'${TB_WHAT}'": ['${_CONTENT_TO_SET}'],"set_auto_refresh_enabled": true}'
    fi

    CRED="-u ${_BAW_ADMINUSER}:${_BAW_ADMINPASSWORD}"
    UPD_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${_BAW_CSRF_TOKEN} -H 'Content-Type: application/json' -d "${_DATA}" -X POST ${_BAW_EXTERNAL_BASE_URL}${_URI})
    
    if [[ "${UPD_RESPONSE}" == *"error_"* ]]; then
      echo ""
      echo "ERROR configuring '${TB_NAME}' details:"
      echo "${UPD_RESPONSE}"
      echo
      exit
    else
      echo " configured !"
    fi
  fi
}

#--------------------------------------------------------------
# remove content of TB
removeTBContent () {
  TB_NAME=$1

  echo -n "Removing content from TeamBinding: "${TB_NAME}" ..."

  _URI="ops/std/bpm/containers/${_BAW_APP}/versions/${_BAW_APP_BRANCH}/team_bindings"
  CRED="-u ${_BAW_ADMINUSER}:${_BAW_ADMINPASSWORD}"
  TB_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${_BAW_CSRF_TOKEN} -H 'Content-Type: application/json' -X GET ${_BAW_EXTERNAL_BASE_URL}${_URI})

  TB_CONTENT=$(echo "${TB_RESPONSE}" | jq -r '.team_bindings[] | select(.name=="'${TB_NAME}'")')
  TB_CONTENT_USERS=$(echo "${TB_CONTENT}" | jq .user_members)
  TB_CONTENT_GROUPS=$(echo "${TB_CONTENT}" | jq .group_members)
  TB_CONTENT_MGR=$(echo "${TB_CONTENT}" | jq .manager_name)

  if [[ "${TB_CONTENT_MGR}" = "null" ]]; then
    TB_CONTENT_MGR="\"\""
  fi

  _DATA='{
  "remove_users": '${TB_CONTENT_USERS}',
  "remove_groups": '${TB_CONTENT_GROUPS}',
  "remove_manager": '${TB_CONTENT_MGR}',
  "set_auto_refresh_enabled": true
  }'

  _URI="ops/std/bpm/containers/${_BAW_APP}/versions/${_BAW_APP_BRANCH}/team_bindings/${TB_NAME}"
  CRED="-u ${_BAW_ADMINUSER}:${_BAW_ADMINPASSWORD}"
  TB_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${_BAW_CSRF_TOKEN} -H 'Content-Type: application/json' -d "${_DATA}" -X DELETE ${_BAW_EXTERNAL_BASE_URL}${_URI})

  if [[ "${TB_RESPONSE}" == *"error_"* ]]; then
    echo ""
    echo "ERROR configuring '${TB_NAME}' details:"
    echo "${TB_RESPONSE}"
    echo
    exit
  else
    echo " done !"
  fi

}

#--------------------------------------------------------------
# update team bindings
updateTeamBindings () {
  _BAW_EXTERNAL_BASE_URL=$(oc get ICP4ACluster -n ${_BAW_DEPL_NAMESPACE} ${_CR_NAME} -o jsonpath='{.status.endpoints}' | jq '.[] | select(.scope == "External") | select(.name | contains("base URL for '${_BAW_DEPL_NAME}'"))' | jq .uri | sed 's/"//g')
  LOGIN_URI="${_BAW_EXTERNAL_BASE_URL}ops/system/login"

  echo "Wait for CSRF token, login to ${LOGIN_URI}"
  until _BAW_CSRF_TOKEN=$(curl -ks -u ${_BAW_ADMINUSER}:${_BAW_ADMINPASSWORD} -X POST -H 'accept: application/json' -H 'Content-Type: application/json' ${LOGIN_URI} -d '{"refresh_groups": true, "requested_lifetime": 7200}' | jq .csrf_token 2>/dev/null | sed 's/"//g') && [[ -n "$_BAW_CSRF_TOKEN" ]]
  do
    echo -n "."
    sleep 1
  done

  for i in {1..10}
  do
    _TB_NAME="BAW_TB_NAME_"$i
    _TB_USERS="BAW_TB_NAME_"$i"_USERS"
    _TB_GROUPS="BAW_TB_NAME_"$i"_GROUPS"
    _TB_MGR_GROUP="BAW_TB_NAME_"$i"_MGR_GROUP"

    if [[ ! -z "${!_TB_NAME}" ]]; then
      echo "---------------------"
      echo "Working on TeamBinding: "${!_TB_NAME}

      if [ "${_REMOVE}" = true ]; then
        removeTBContent ${!_TB_NAME}
      fi  

      updateTB "add_users" ${!_TB_NAME} ${!_TB_USERS}
      updateTB "add_groups" ${!_TB_NAME} ${!_TB_GROUPS}
      updateTB "add_manager" ${!_TB_NAME} "${!_TB_MGR_GROUP}"
    fi
  done

  echo ""
}

#--------------------------------------------------------

#==========================================
echo ""
echo "*************************************"
echo "***** BAW Team Bindings Update *****"
echo "*************************************"
echo "Using team bindings file: "${_TEAM_BINDINGS_FILE}

if [[ -z "${_BAW_DEPL_NAMESPACE}" ]] || [[ -z "${_BAW_DEPL_NAME}" ]] || [[ -z "${_CR_NAME}" ]] || [[ -z "${_BAW_ADMINUSER}" ]] || [[ -z "${_BAW_ADMINPASSWORD}" ]] || [[ -z "${_BAW_APP}" ]] || [[ -z "${_BAW_APP_BRANCH}" ]] || [[ -z "${_TEAM_BINDINGS_FILE}" ]]; then
  echo "ERROR: Empty values for required parameter"
  usage
  exit 1
fi
if [[ ! -f "${_TEAM_BINDINGS_FILE}" ]]; then
  echo "ERROR: file not found: ${_TB}"
  exit 1
fi

source ${_TEAM_BINDINGS_FILE}

echo ""
echo "Working on acronym ["${_BAW_APP}"] snapshot["${_BAW_APP_BRANCH}"]"
echo ""

updateTeamBindings


#!/bin/bash

_me=$(basename "$0")

_CTRL_PLANE=false
_WORKERS=false

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;32m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

#--------------------------------------------------------
# read command line params
while getopts cw flag
do
    case "${flag}" in
        c) _CTRL_PLANE=true;;
        w) _WORKERS=true;;
    esac
done

#------------------------
listNodes () {
  _NT=$1
  _FILE=$2
  _FILE2="${_FILE}-2"

  if [[ -z "${_FILE}" ]]; then
    echo "ERROR: no file name"
    exit
  fi
  if [[ "worker" = "${_NT}" ]] || [[ "master" = "${_NT}" ]]; then
    echo "" > ${_FILE}
    oc get nodes --no-headers | grep ${_NT} | awk '{print $1"\n"}' | xargs echo >> ${_FILE}
    
    # because of 'sed -i' in Darwin platform
    # sed 's/ /\n/g' -i ${_FILE}
    # sed '/^$/d' -i ${_FILE}

    cat ${_FILE} | sed 's/ /\n/g' > ${_FILE2}
    cat ${_FILE2} | sed '/^$/d' > ${_FILE}
    rm ${_FILE2}

  else
    echo "ERROR: node type must be 'worker' or 'master'"
    exit
  fi
}

#------------------------
rebootNode () {
  NODE_NAME=$1
  echo "#----------------------------------"
  echo -e "${_CLR_GREEN}Cordoning and rebooting node: '${NODE_NAME}'${_CLR_NC}"
  oc adm cordon $NODE_NAME
  oc adm drain --ignore-daemonsets --delete-emptydir-data --force --disable-eviction $NODE_NAME
  echo "Wait $DELAY_BEFORE_REBOOT seconds before rebooting the node..."
  sleep $DELAY_BEFORE_REBOOT
  oc debug node/$NODE_NAME -- chroot /host systemctl reboot --reboot-argument=now
  echo "Wait $DELAY_AFTER_REBOOT seconds for node rebooting..."
  sleep 5
  echo "Uncordoning and enable scheduling on node: "$NODE_NAME
  oc adm uncordon $NODE_NAME
  oc patch node/${NODE_NAME} --type=merge -p '{"spec": {"unschedulable":false}}'
}

#------------------------
rebootNodes () {
  while read -r NODE_NAME;
  do
    if [[ ! -z "$NODE_NAME" ]]; then
      rebootNode $NODE_NAME
    fi
  done < $1
  
}

#========================
oc project default
DELAY_BEFORE_REBOOT=5
DELAY_AFTER_REBOOT=60
TMP_OUT_FILE="/tmp/cp4ba-utils-nodes-$USER-$RANDOM"

echo "#======================================="
echo "Reboot nodes: workers[${_WORKERS}] control[${_CTRL_PLANE}]"
echo ""
if [[ "${_WORKERS}" = "false" ]] && [[ "${_CTRL_PLANE}" = "false" ]]; then
  echo -e "${_CLR_RED}Nothing to do, use one or both parameters: ${_CLR_YELLOW}'-c'${_CLR_RED} for control-plane, ${_CLR_YELLOW}'-w'${_CLR_RED} for workers${_CLR_NC}"
  echo "usage: $_me -c -w"
  echo ""
  exit
fi
if [[ "${_WORKERS}" = "true" ]]; then
  listNodes "worker" ${TMP_OUT_FILE}
  echo -e "${_CLR_YELLOW}Nodes for worker:${_CLR_NC}"
  cat ${TMP_OUT_FILE}
  rebootNodes ${TMP_OUT_FILE}
  rm ${TMP_OUT_FILE}
fi

if [[ "${_CTRL_PLANE}" = "true" ]]; then
  listNodes "master" ${TMP_OUT_FILE}
  echo ""
  echo -e "${_CLR_YELLOW}Nodes for master:${_CLR_NC}"

  cat ${TMP_OUT_FILE}
  rebootNodes ${TMP_OUT_FILE}
  rm ${TMP_OUT_FILE}
fi


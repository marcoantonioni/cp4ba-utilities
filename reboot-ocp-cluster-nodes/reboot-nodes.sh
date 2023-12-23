#!/bin/bash

_me=$(basename "$0")

_CTRL_PLANE=false

#--------------------------------------------------------
# read command line params
while getopts c flag
do
    case "${flag}" in
        c) _CTRL_PLANE=true;;
    esac
done

#------------------------
listNodes () {
  _NT=$1
  _FILE=$2

  if [[ -z "${_FILE}" ]]; then
    echo "ERROR: no file name"
    exit
  fi
  if [[ "worker" = "${_NT}" ]] || [[ "master" = "${_NT}" ]]; then
    echo "" > ${_FILE}
    oc get nodes --no-headers | grep ${_NT} | awk '{print $1"\n"}' | xargs echo >> ${_FILE}
    sed 's/ /\n/g' -i ${_FILE}
    sed '/^$/d' -i ${_FILE}
  else
    echo "ERROR: node type must be 'worker' or 'master'"
    exit
  fi
}

#------------------------
rebootNode () {
  NODE_NAME=$1
  echo "#----------------------------------"
  echo "Cordoning and rebooting node: "$NODE_NAME
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
TMP_OUT_FILE="./nodes-list"

echo "#======================================="
listNodes "worker" ${TMP_OUT_FILE}
echo "Nodes for worker:"
cat ${TMP_OUT_FILE}
rebootNodes ${TMP_OUT_FILE}
rm ${TMP_OUT_FILE}

if [[ "${_CTRL_PLANE}" = "true" ]]; then
  listNodes "master" ${TMP_OUT_FILE}
  echo ""
  echo "Nodes for master:"

  cat ${TMP_OUT_FILE}
  rebootNodes ${TMP_OUT_FILE}
  rm ${TMP_OUT_FILE}
fi


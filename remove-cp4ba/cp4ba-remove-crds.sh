#!/bin/bash
echo "=================================="
echo "Removing IBM CRDs (icp4a, rpa, mq)"
echo ""
# -n 1
read -p "WARNING Unrecoverable action ! Are you sure ? (Yes/No) " -r
echo ""
REPLY=$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')
if [[ "$REPLY" = "yes" ]]; then
  echo "Removing CRDs in group: icp4a.ibm.com"
  oc get crd | grep "icp4a.ibm.com" | awk '{print $1}' | xargs oc delete crd 2>/dev/null
  echo "Removing CRDs in group: rpa.automation.ibm.com"
  oc get crd | grep "rpa.automation.ibm.com" | awk '{print $1}' | xargs oc delete crd 2>/dev/null
  echo "Removing CRDs in group: mq.ibm.com"
  oc get crd | grep "mq.ibm.com" | awk '{print $1}' | xargs oc delete crd 2>/dev/null
fi

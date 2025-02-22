# cp4ba-tls-entry-point

```
usage: 
    -n target-namespace
    -z target-zenservice-name
    -s target-new-secret-name 
    -f (optional) source-secret-name
    -k (optional) source-secret-namespace
    -x (optional) no-wait-after-update
    -w (mutually exclusive with update operation) wait-progress
```

## Mandatory parameters

target-*

Target namespace, ZenService name, TLS secret to apply to Zen route 

## Optional parameters

source-*

Optional when the secret to apply already exists in target namespace


## IBM TECHZONE - Update certificate for ZenService entry point
Clone the secret from namespace 'openshift-ingress'.

The secret name is in the form 'itz-<OCP_CLUSTER_NAME>-serving-cert'

Get secret name
```
CERT_TNS_ORIGIN=openshift-ingress
OCP_CLUSTER_NAME=$(oc cluster-info | sed 's/.*https:\/\/api.itz-//g' | sed 's/\..*//g' | head -n1)
echo "Name: "${OCP_CLUSTER_NAME}
LE_SECRET_NAME="itz-${OCP_CLUSTER_NAME}-serving-cert"
oc get secret --no-headers -n ${CERT_TNS_ORIGIN} ${LE_SECRET_NAME}
```

Update ZenService instance 'iaf-zen-cpdservice'
```
CERT_TNS_DEST=cp4ba-demo
./cp4ba-tls-update-ep.sh -n ${CERT_TNS_DEST} -z iaf-zen-cpdservice -s my-letsencrypt -f ${LE_SECRET_NAME} -k ${CERT_TNS_ORIGIN}
```

## Update certificate for ZenService entry point, clone the secret from existing one

```
./cp4ba-tls-update-ep.sh -n cp4ba-daffy-prod -z iaf-zen-cpdservice -s my-letsencrypt -f letsencrypt-certs -k openshift-config
```

## Update certificate for ZenService entry point, use an already present secret

```
./cp4ba-tls-update-ep.sh -n cp4ba-daffy-prod -z iaf-zen-cpdservice -s my-letsencrypt
```

## Wait for update progress of ZenService entry point, for previous update command 

```
./cp4ba-tls-update-ep.sh -n cp4ba-daffy-prod -z iaf-zen-cpdservice -w
```

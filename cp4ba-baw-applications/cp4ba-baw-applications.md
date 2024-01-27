# cp4ba-baw-applications

Common vars
```
_NS="your-namespace"
_BAW_NAME="baw-instance-name"
_CR_NAME="cr-icp4a-name"
```

## 1. Deploy application
```
./cp4ba-deploy-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a ../../cp4ba-wfps/apps/SimpleDemoBawWfPS.zip
```

## 2. List applications & versions

### 2.1 Example for list of 'Acronym - Name'
```
./cp4ba-list-baw-apps.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s
```

### 2.1 Example for list of all details
```
./cp4ba-list-baw-apps.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -d
```

### 2.3 Example for list of versions of an application 'Acronym - Name - Snapshot'
```
./cp4ba-list-baw-apps.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA
```

### 2.4 Example for list of detailed versions of an application 'Acronym - Name - Snapshot'
```
./cp4ba-list-baw-apps.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -d
```


## 3. Activate application
```
./cp4ba-update-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -o activate
```

Activate and make 'default'
```
./cp4ba-update-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -o activate -m
```


## 4. Deactivate application
```
./cp4ba-update-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -o deactivate
```

Force deactivation
```
./cp4ba-update-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -o deactivate -f
```

## 5. Undeploy application
```
./cp4ba-undeploy-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7
```

Force undeploy (you must deactivate it before run this command)
```
./cp4ba-undeploy-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -f
```

## 6. Update Team Bindings
Add users/groups
```
./cp4ba-baw-update-team-bindings.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -t ./configs/team-bindings-app-1.properties

```
Forces removal of the previous configuration then add users/groups
```
./cp4ba-baw-update-team-bindings.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -t ./configs/team-bindings-app-1.properties -r

```



# cp4ba-baw-applications

Common vars
```
_NS="your-namespace"
_BAW_NAME="baw-instance-name"
_CR_NAME="cr-icp4a-name"
_APP_FILE="./apps/DemoCaseWorkflowDocuments.zip"
_DOS="design-object-store"
_ENV="target-environment"
```

## 1. Deploy application

### 1.1 Workflow application
```
./cp4ba-deploy-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a ${_APP_FILE}
```

### 1.2 Case application
```
./cp4ba-deploy-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a ${_APP_FILE} -d ${_DOS} -e ${_ENV}
```

Forces overwrite case artifact
```
./cp4ba-deploy-baw-app.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a ${_APP_FILE} -d ${_DOS} -e ${_ENV} -f
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

# case solution
./cp4ba-baw-update-team-bindings.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a DCWD -v V1.0 -t ./configs/team-bindings-app-2.properties
```
Forces removal of the previous configuration then add users/groups
```
./cp4ba-baw-update-team-bindings.sh -n ${_NS} -b ${_BAW_NAME} -c ${_CR_NAME} -u cp4admin -p dem0s -a SDWPSBA -v 0.7 -t ./configs/team-bindings-app-1.properties -r

```

# IBM Business Automation Workflow Case REST Interface
Navigate to

https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/bpm/explorer/

then from swagger explore field

https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/case/docs


# To Be Implemented
```

# lista soluzioni
curl -X 'GET' \
  'https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/CaseManager/CASEREST/v2/solutions' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: ey....'

{
  "Solutions": [
    {
      "Status": "Completed",
      "Description": "Demo generica per funzionalità di \\n\\n- Workflow autorizzativo\\n\\n- Gestione documenti associati a Case/Processo\\n\\n- Commenti al case da parte dei vari partecipanti\\n\\n- Gestione dinamica dei partecipanti ai Team/Ruoli del processo",
      "TargetOS": "BAWINS1TOS",
      "WebAppID": "11",
      "SolutionPrefix": "DCWD",
      "SolutionName": "DemoCaseWorkflowDocuments",
      "SolutionFolderId": "{8D4F3B00-0000-C166-A7F8-F9486D49FC4D}",
      "IntegrationType": "P8",
      "PEConnectionPoint": "pe_conn_tos"
    }
  ]
}

# deploy
curl -X 'POST' \
  'https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/CaseManager/CASEREST/v2/solutions?solutionAcronym=DCWD&ConnectionDefinitionName=target_env' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: ey....' \
  -d ''

# depl status
curl -X 'GET' \
  'https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/CaseManager/CASEREST/v2/solution/DCWD/deploymentstatus?TargetObjectStore=BAWINS1TOS' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: ey....'

{
  "Status": "Completed",
  "ConnectionDefinitionId": "{8D4F5AF0-0008-CAA1-8E43-AF0063C45A9D}",
  "TestUrl": "https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/icn/navigator/?desktop=baw&feature=Cases&tos=BAWINS1TOS&solution=DCWD",
  "Synchronized": true,
  "SolutionId": "{8D4E74C0-0002-C2A6-B1E0-A6CD1BD3F4C9}",
  "PeConfigId": "{6EB970FA-59BC-4F1E-BA13-BE5314B46889}",
  "Name": "DemoCaseWorkflowDocuments",
  "DateLastModified": "2024-01-28T11:48:36Z"
}

# import manifest
curl -X 'POST' \
  'https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/CaseManager/CASEREST/v2/solution/importManifest' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: ey....' \
  -H 'Content-Type: multipart/form-data' \
  -F 'manifest=@DemoCaseWorkflowDocuments_securityManifest.zip;type=application/zip'

{
  "Status": "The manifest was imported successfully."
}


# apply manifest
curl -X 'POST' \
  'https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/CaseManager/CASEREST/v2/solution/DCWD/applyManifest?ConnectionDefinitionName=target_env&manifestName=MySecCfgDCWD&manifestType=security' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: ey....' \
  -d ''

{
  "Status": "The MySecCfgDCWD security configuration was applied successsfully."
}


# fetch casetype properties
curl -X 'GET' \
  'https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/CaseManager/CASEREST/v2/casetype/DCWD_GestioneRichiesta/properties?TargetObjectStore=BAWINS1TOS' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: ey....'

{
  "CaseType": "DCWD_GestioneRichiesta",
  "Properties": [
    {
      "SymbolicName": "DCWD_DescrizioneRichiesta",
      "Data": {
        "Cardinality": "single",
        "PropertyType": "string",
        "Value": null
      }
    },
    {
      "SymbolicName": "DCWD_DataLimite",
      "Data": {
        "Cardinality": "single",
        "PropertyType": "datetime",
        "Value": null
      }
    },
    {
      "SymbolicName": "DCWD_AvviaGestioneRichiesta",
      "Data": {
        "Cardinality": "single",
        "PropertyType": "boolean",
        "Value": false
      }
    },
    {
      "SymbolicName": "DCWD_TipoRichiesta",
      "Data": {
        "Cardinality": "single",
        "PropertyType": "string",
        "Value": "T_A",
        "ChoiceList": {
          "Choices": [
            {
              "ChoiceName": "Tipo A",
              "Value": "T_A"
            },
            {
              "ChoiceName": "Tipo B",
              "Value": "T_B"
            },
            {
              "ChoiceName": "Tipo C",
              "Value": "T_C"
            }
          ],
          "DisplayName": "DCWD_TipologiaRichiesta"
        },
        "Required": true
      }
    }
  ]
}

# start case

curl -X 'POST' \
  'https://cpd-cp4ba-baw-double-pfs.apps.subdomain.cloud.techzone.ibm.com/baw-baw1/CaseManager/CASEREST/v2/case' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: ey....' \
  -H 'Content-Type: application/json' \
  -d '{
  "TargetObjectStore": "BAWINS1TOS",
  "CaseType": "DCWD_GestioneRichiesta",
  "ReturnUpdates": false,
  "Properties": [
    {
      "SymbolicName": "DCWD_DescrizioneRichiesta",
      "Value": "Marco"
    },
    {
      "SymbolicName": "DCWD_TipoRichiesta",
      "Value": "T_A"
    }
  ]
}
'

```


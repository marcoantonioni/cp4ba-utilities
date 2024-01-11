# configure-bastudio-ci-cd

Sequence of operations to configure BAStudio with GIT for CI/CD.

# Steps

## 1. Create Github auth data

Set your data in env vars _GIT_USER_ID, _GIT_TOKEN, _GIT_REPO_NAME
```
_GIT_USER_ID="your-git-id"
_GIT_TOKEN="your-git-token eg: ghp_...pb"
_GIT_REPO_NAME="your-repo-name"
```

Set output folder for auth data file and certificate
```
_GIT_CI_CD_CFG_FOLDER="./ci-cd-output"
mkdir -p ${_GIT_CI_CD_CFG_FOLDER}
```

Set CI/CD values
```
_GIT_AUTH_SECRET_NAME="my-git-auth"
_GIT_TLS_SECRET_NAME="my-git-tls"
_GIT_REPO_URL="https://api.github.com/${_GIT_USER_ID}/${_GIT_REPO_NAME}"
_GIT_AUTH_DATA_FILE="${_GIT_CI_CD_CFG_FOLDER}/auth-data.xml"
_GIT_CERT_FILE="${_GIT_CI_CD_CFG_FOLDER}/git.cert"
```
Create the xml auth data file
```
echo '<?xml version="1.0" encoding="UTF-8"?>
  <server>
    <authData alias="git_user" 
              id="git_user" 
              user="'${_GIT_USER_ID}'" 
              password="'${_GIT_TOKEN}'"/>
  </server>' > ${_GIT_AUTH_DATA_FILE}
```


## 2. Grab GitHub certificate

```
openssl s_client -showcerts -connect github.com:443 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${_GIT_CERT_FILE}
```

## 3. Create secrets

Update with your namespace
```
_BASTUDIO_NAMESPACE="set-your-namespace"

oc delete secret -n ${_BASTUDIO_NAMESPACE} ${_GIT_AUTH_SECRET_NAME} 2>/dev/null
oc delete secret -n ${_BASTUDIO_NAMESPACE} ${_GIT_TLS_SECRET_NAME} 2>/dev/null

# auth data
oc create secret generic -n ${_BASTUDIO_NAMESPACE} ${_GIT_AUTH_SECRET_NAME} --from-file=sensitiveCustom.xml=${_GIT_AUTH_DATA_FILE}

# delete file wth your access token
rm ${_GIT_AUTH_DATA_FILE}

# tls
oc create secret generic -n ${_BASTUDIO_NAMESPACE} ${_GIT_TLS_SECRET_NAME} --from-file=tls.crt=${_GIT_CERT_FILE}
```

## 4. Update CP4A CR

### 4.1 section 'bastudio_configuration'
Note: the '<b>git-endpoint-url</b>' value should have "api.github.com" instead of "github.com"

Use the echo command to generate a complete substitution of values
```
echo '
  bastudio_configuration:
    bastudio_custom_xml: |+
      <properties>
        <server>
          <git-configuration merge="mergeChildren">
            <git-endpoint-url>'${_GIT_REPO_URL}'</git-endpoint-url>
            <git-auth-alias-name>git_user</git-auth-alias-name>
          </git-configuration>
        </server>
      </properties>
    custom_secret_name: '${_GIT_AUTH_SECRET_NAME}'
    tls:
      tlsTrustList: ['${_GIT_TLS_SECRET_NAME}']'
```

cut&paste the generated snippet into CR

### 4.2 section 'shared_configuration'

Enable internet access, set 'sc_restricted_internet_access' to 'false'
```
  shared_configuration:
    sc_egress_configuration:
      ...
      sc_restricted_internet_access: false
```

## 5. Apply updated yaml sections to CR and wait for a reconciliation

Wait until a new bastudio pod is created.


## 6. verify the configuration in the bastudio pod

rsh into pod, for example
```
oc rsh -n ${_BASTUDIO_NAMESPACE} icp4adeploy-bastudio-deployment-0 /bin/bash

cat /opt/ibm/wlp/usr/servers/defaultServer/TeamWorksConfiguration.running.xml | egrep -B4 -A4 "git-endpoint-url|git-auth-alias-name"

cat /opt/ibm/wlp/usr/shared/resources/sensitive-custom/sensitiveCustom1.xml | grep "authData"

exit
```

# References

CP4BA (WARNING the xml snippet is missing the attribute --> alias="git_user" <-- as of 2024-01-10)

[https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=projects-configuring-cicd-integration](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=projects-configuring-cicd-integration)



BAW

[https://www.ibm.com/docs/en/baw/23.x?topic=projects-configuring-cicd-integration](https://www.ibm.com/docs/en/baw/23.x?topic=projects-configuring-cicd-integration)


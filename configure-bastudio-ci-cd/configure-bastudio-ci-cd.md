# configure-bastudio-ci-cd

<i>Last update: 2024-01-11</i>

Sequence of operations to configure BAStudio with GIT for CI/CD.

# Access token, how to

In my tests against GitHub I've created a classic token using the following scope

```
repo                Full control of private repositories
  repo:status       Access commit status
  repo_deployment   Access deployment status
  public_repo       Access public repositories
  repo:invite       Access repository invitations
  security_events   Read and write security events
```

the generated token can be used as plain text for 'authData.password' attribute in xml auth data file.


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

Set CI/CD values with your values (pay attention here, must use: https://api.github.com/repos)
```
_GIT_AUTH_SECRET_NAME="my-git-auth"
_GIT_TLS_SECRET_NAME="my-git-tls"
_GIT_REPO_URL="https://api.github.com/repos/${_GIT_USER_ID}/${_GIT_REPO_NAME}"
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


## 2. Save GitHub certificate

The saved certificate will be added into trusted list for BAStudio deployment.

```
openssl s_client -showcerts -connect github.com:443 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${_GIT_CERT_FILE}
```

## 3. Create secrets

Update with your namespace
```
_BASTUDIO_NAMESPACE="set-your-namespace"
```

### 3.1 auth data secret
```
oc delete secret -n ${_BASTUDIO_NAMESPACE} ${_GIT_AUTH_SECRET_NAME} 2>/dev/null
oc create secret generic -n ${_BASTUDIO_NAMESPACE} ${_GIT_AUTH_SECRET_NAME} --from-file=sensitiveCustom.xml=${_GIT_AUTH_DATA_FILE}

# !!! (optional) delete file wth your access token from your local storage
rm ${_GIT_AUTH_DATA_FILE}
```

### 3.2 tls secret
```
oc delete secret -n ${_BASTUDIO_NAMESPACE} ${_GIT_TLS_SECRET_NAME} 2>/dev/null
oc create secret generic -n ${_BASTUDIO_NAMESPACE} ${_GIT_TLS_SECRET_NAME} --from-file=tls.crt=${_GIT_CERT_FILE}
```

## 4. Update CP4A CR

You must update the following 'bastudio_configuration' sections

- bastudio_custom_xml
- custom_secret_name
- tlsTrustList

May be, in 'starter' deployment authoring environment, you have not the section 'bastudio_configuration' so add entire snippet under 'spec' sction.

You may should also update 'shared_configuration' section to enable external IP access.

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

Cut&Paste the generated snippet into CR

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

# Troubleshooting

In case of resource not found with 404 error code check the complete url of your repository (must begin with https://api.github.com/repos for GitHub, adapt for your remote server).

In case of failed authentication you will see a 401 error code. Verify the tag values of your 'authData' xml file. 
```
[2024-01-11T10:55:31.507+0000] 0000003a com.ibm.bpm.processcenter.api.ArtifactManagementApiImpl      E exception during checking the Json descriptor file in git
[2024-01-11T10:55:31.507+0000] 0000003a com.ibm.bpm.processcenter.api.ArtifactManagementApiImpl      E Exception during pushing Json descriptor file to git
java.io.IOException: Server returned HTTP response code: 401 for URL: https://api.github.com/repos/marcoantonioni/test-cp4ba-git/contents/workflow/SDSTPWP/0.2_descriptor.json
        at java.base/jdk.internal.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
        at java.base/jdk.internal.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:77)
```

# Example of repo contents after first 'Push to Git' from BAStudio

You may access the contents accessing your repo url appending 'contents/workflow/' an then the acronym of an app (in my test 'GTW')
```
https://api.github.com/repos/marcoantonioni/test-cp4ba-git/contents/workflow/GTW/1_descriptor.json
```

Example of '1_descriptor.json' contents
```
{
  "name": "1_descriptor.json",
  "path": "workflow/GTW/1_descriptor.json",
  "sha": "68ee3f67cdcb3fdcdc8b1cca1af40cc3db284760",
  "size": 699,
  "url": "https://api.github.com/repos/marcoantonioni/test-cp4ba-git/contents/workflow/GTW/1_descriptor.json?ref=main",
  "html_url": "https://github.com/marcoantonioni/test-cp4ba-git/blob/main/workflow/GTW/1_descriptor.json",
  "git_url": "https://api.github.com/repos/marcoantonioni/test-cp4ba-git/git/blobs/68ee3f67.....3db284760",
  "download_url": "https://raw.githubusercontent.com/marcoantonioni/test-cp4ba-git/main/workflow/GTW/1_descriptor.json",
  "type": "file",
  "content": "eyJzbmFwc2hvdF9uYW1lIjoi..........vdWQudGVjaHpvbmUuaWJtLmNvbSJ9\n",
  "encoding": "base64",
  "_links": {
    "self": "https://api.github.com/repos/marcoantonioni/test-cp4ba-git/contents/workflow/GTW/1_descriptor.json?ref=main",
    "git": "https://api.github.com/repos/marcoantonioni/test-cp4ba-git/git/blobs/68ee3........84760",
    "html": "https://github.com/marcoantonioni/test-cp4ba-git/blob/main/workflow/GTW/1_descriptor.json"
  }
}
```


# References

CP4BA (WARNING the xml snippet is missing the attribute --> alias="git_user" <-- as of 2024-01-10)

[https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=projects-configuring-cicd-integration](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=projects-configuring-cicd-integration)


BAW

[https://www.ibm.com/docs/en/baw/23.x?topic=projects-configuring-cicd-integration](https://www.ibm.com/docs/en/baw/23.x?topic=projects-configuring-cicd-integration)


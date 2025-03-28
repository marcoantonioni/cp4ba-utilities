# cp4ba-utilities

Utilities for IBM Cloud Pak® for Business Automation

<i>Last update: 2025-03-28</i>


1. cp4ba-remove-namespace.sh

    Removes contents and deletes a namespace. Cleans all CP4BA resources on its own.
    
    Updated for v24.x

2. reboot-nodes.sh

    Reboots nodes of the Openshift cluster. It is possible to select between workers, master and both.

3. [configure-bastudio-ci-cd](/configure-bastudio-ci-cd/configure-bastudio-ci-cd.md)

    Sequence of operations to configure BAStudio with GIT for CI/CD.

4. cp4ba-baw-applications.sh (Workflow / Case)

    Applications management (list/deploy/activate/deactivate/undeploy/teambindings)

5. [cp4ba-tls-entry-point](/cp4ba-tls-entry-point/cp4ba-tls-entry-point.md)

    Update ZenService endpoint TLS certificate

    See: [Custom Cloud Pak Platform UI (Zen) Route and certificates](https://www.ibm.com/docs/en/cloud-paks/1.0?topic=ac-custom-cloud-pak-platform-ui-zen-route-certificates)

6. [nginx-proxy-custom](/nginx-proxy-custom/README.md)

    Proxy used to log content and headers sent by BPMRESTRequest (BAW service) or other OpenAPI implementations 

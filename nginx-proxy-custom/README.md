# nginx-proxy-custom

## Build & run image
```
IMG_NAME=nginx-proxy-custom:latest

podman build -f ./Dockerfile -t quay.io/marco_antonioni/${IMG_NAME} .

podman login -u $QUAY_USER -p $QUAY_PWD quay.io
podman push quay.io/marco_antonioni/${IMG_NAME}

podman run --name nginx-proxy-custom -i --rm -p 8080:8080 quay.io/marco_antonioni/${IMG_NAME}

podman exec -it nginx-proxy-custom /bin/bash
```

## Tests
```
curl -d '{"key1":"value1", "key2":"value2"}' -H "Content-Type: application/json" -X POST http://localhost:8080

curl -v -k -H 'accept: */*' -H 'Content-Type: multipart/form-data' -F 'files=@./files/file1.txt;type=text/plain' -X 'POST' http://localhost:8080


```

## Deploy to OCP
```
RES_NAME=nginx-proxy-custom
oc delete deployment ${RES_NAME}
oc delete service ${RES_NAME}

cat <<EOF | oc create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ${RES_NAME}
  name: ${RES_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${RES_NAME}
  template:
    metadata:
      labels:
        app: ${RES_NAME}
    spec:
      serviceAccountName: ibm-cp4ba-anyuid
      securityContext:
        runAsNonRoot: false
      containers:
      - image: quay.io/marco_antonioni/${IMG_NAME}
        imagePullPolicy: Always
        name: ${RES_NAME}
EOF

oc expose deployment ${RES_NAME} --port=8080

```

```
tail -n 1000 -f /var/log/nginx/postdata.log

echo "This is a test buffer !" > /tmp/file1.txt
curl -v -k -H 'accept: */*' -H 'Content-Type: multipart/form-data' -F 'files=@/tmp/file1.txt;type=text/plain' -X 'POST' http://nginx-proxy-custom:8080/upload
```

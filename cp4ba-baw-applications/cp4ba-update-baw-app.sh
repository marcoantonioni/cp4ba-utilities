#!/bin/bash

curl -X 'POST' \
  'https://cpd-cp4ba-wfps-baw-pfs-demo.apps.65903a5ec75eb10011ecb9f9.cloud.techzone.ibm.com/baw-baw1/ops/std/bpm/containers/SDWPSBA/versions/0.7/deactivate?force=true' \
  -H 'accept: application/json' \
  -H 'BPMCSRFToken: eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3MDU1OTUyMjIsInN1YiI6ImNwNGFkbWluIn0.Je2H3va_JKJ54o9o5iDhnRiSZ89bGTc99FOj2K1dENU' \
  -d ''
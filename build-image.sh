#!/bin/bash

podman build . -t registry.home/steamapps/valheim-server:0.1
podman push --tls-verify=false registry.home/steamapps/valheim-server:0.1

kubectl rollout restart deployment -n games valheim-dedicated-server

sleep 10

kubectl logs -n games -l app.kubernetes.io/instance=valheim-dedicated-server --follow

#!/bin/bash

docker build . -t registry.home/steamapps/valheim-server:1.6.9
docker push registry.home/steamapps/valheim-server:1.6.9

#kubectl rollout restart statefulset -n games valheim-dedicated-server

#sleep 20

#kubectl logs -n games -l app.kubernetes.io/instance=valheim-dedicated-server --follow

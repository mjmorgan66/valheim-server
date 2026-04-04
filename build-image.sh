#!/bin/bash

VERSION=1.6.12

docker build . -t registry.home/steamapps/valheim-server:$VERSION
docker push registry.home/steamapps/valheim-server:$VERSION

#kubectl rollout restart statefulset -n games valheim-dedicated-server

#sleep 20

#kubectl logs -n games -l app.kubernetes.io/instance=valheim-dedicated-server --follow

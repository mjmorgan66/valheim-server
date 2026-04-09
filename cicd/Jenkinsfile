#!groovy

@Library('jenkins-library') _

def LABEL= "label_goes_here"

def container = [
    containerTemplate(
      name: 'busybox',
      image: 'busybox',
      ttyEnabled: true,
      command: 'cat'
    )
  ]
podTemplate(
    label: LABEL,
    containers: container,
    //volumes: volumes,
    serviceAccount: 'jenkins',
    yaml: '''
    spec:
      securityContext:
        fsGroup: 1000
    ''') {
        timeout(time:10, unit: 'MINUTES') {
            node(LABEL) {
                checkout scm
                println("calling entrypoint...")
                entrypoint()
                println("done calling entrypoing")
                println("testing update!")
            }
        }
}

#!/usr/bin/env bash

# Choose which demos to run
DEMOS="1 2 3 4 5"

while getopts ":z:" opt; do
  case $opt in
    x)
      CLEANUP=true
      ;;
    z)
      DEMOS=$OPTARG
      ;;
  esac
done

# https://github.com/paxtonhare/demo-magic
. demo-magic.sh
TYPE_SPEED=100

# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

### Demo 1
if [[ $DEMOS == *"1"* ]]; then
  title="Demo 1 - Hello World with Knative Serving"
  echo $title

  pe "cat 01-helloworld/helloworld.yaml"
  pe "kubectl apply -f 01-helloworld/helloworld.yaml"
  for i in {1..2}; do
    pe "kubectl -n default get ksvc"
    sleep 3
  done
  echo "..."
  echo
  wait
  clear

  export HOST_URL=$(kubectl -n default get ksvc helloworld-go --output jsonpath='{.status.domain}')
  export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

  echo $title
  pe "curl -H \"Host: ${HOST_URL}\" http://${IP_ADDRESS}/"
  wait
  clear

  echo $title
  pe "kubectl -n default get configuration"
  pe "kubectl -n default get revision"
  pe "kubectl -n default get route"
  pe "kubectl -n default edit ksvc helloworld-go"
  pe "kubectl -n default get revision"
  sleep 5
  pe "curl -H \"Host: ${HOST_URL}\" http://${IP_ADDRESS}/"
  wait
  clear

  kubectl delete -f 01-helloworld/ &>/dev/null
fi

### Demo 2
if [[ $DEMOS == *"2"* ]]; then
  title="Demo 2 - Autoscaling with Knative Serving"
  echo $title

  pe "cat 02-autoscaling/autoscale.yaml"
  pe "kubectl apply -f 02-autoscaling/autoscale.yaml"
  for i in {1..2}; do
    pe "kubectl -n default get route"
    sleep 3
  done
  echo "..."
  wait
  clear

  export HOST_URL=$(kubectl -n default get ksvc autoscale-go --output jsonpath='{.status.domain}')
  export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

  echo $title
  pe "curl -H \"Host: ${HOST_URL}\" http://${IP_ADDRESS}/?sleep=5&prime=10000&bloat=5"
  wait
  clear

  echo "$title: Generating load"
  pe "kubectl get pod"
  hey -z 10s -c 50 -host "${HOST_URL}" "http://${IP_ADDRESS?}?sleep=100&prime=10000&bloat=5" >/dev/null &
  p "hey -z 10s -c 50 -host \"${HOST_URL}\" \"http://${IP_ADDRESS?}?sleep=100&prime=10000&bloat=5\" &"
  pe "kubectl get pod -w"
  pe "kubectl get pod"
  wait
  clear

  kubectl delete -f 02-autoscaling/ &>/dev/null
fi

### Demo 3
if [[ $DEMOS == *"3"* ]]; then
  title="Demo 3 - Blue/Green deployment with Serving"
  echo "$title: Create the configuration"

  pe "cat 03-bluegreen/01-blue-green-demo-config.yaml"
  pe "kubectl apply -f 03-bluegreen/01-blue-green-demo-config.yaml"
  echo
  wait
  clear

  echo "$title: Create the route"
  export REV01=$(kubectl get config blue-green-demo -o 'jsonpath={.status.latestCreatedRevisionName}')
  pe "cat 03-bluegreen/02-blue-green-demo-route.yaml"
  pe "cat 03-bluegreen/02-blue-green-demo-route.yaml | sed \"s/blue-green-demo-00001/$REV01/\" | kubectl apply -f -"
  pe "kubectl get route"

  export HOST_URL=blue-green-demo.default.example.com
  export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

  pe "curl -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\""
  wait
  clear

  echo "$title: Change the configuration for green deployment"
  pe "cat 03-bluegreen/03-blue-green-demo-config.yaml"
  pe "kubectl apply -f 03-bluegreen/03-blue-green-demo-config.yaml"
  pe "kubectl get revision"
  export REV02=$(kubectl get config blue-green-demo -o 'jsonpath={.status.latestCreatedRevisionName}')
  pe "curl -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\""
  echo
  wait
  clear

  echo "$title: Update route"
  pe "cat 03-bluegreen/04-blue-green-demo-route.yaml"
  pe "cat 03-bluegreen/04-blue-green-demo-route.yaml | sed \"s/blue-green-demo-00001/$REV01/\" | sed \"s/blue-green-demo-00002/$REV02/\" | kubectl apply -f -"
  pe "curl -H \"Host: v2.${HOST_URL}\" \"http://${IP_ADDRESS}/\""
  wait
  clear

  echo "$title: Send 50% traffic to green and 50% to blue"
  pe "cat 03-bluegreen/05-blue-green-demo-route.yaml"
  pe "cat 03-bluegreen/05-blue-green-demo-route.yaml | sed \"s/blue-green-demo-00001/$REV01/\" | sed \"s/blue-green-demo-00002/$REV02/\" | kubectl apply -f -"
  pe "curl -s --raw -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\" | grep class"
  pe "curl -s --raw -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\" | grep class"
  pe "curl -s --raw -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\" | grep class"
  pe "curl -s --raw -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\" | grep class"
  wait
  clear

  echo "$title: Send 100% traffic to green and 0% to blue"
  pe "cat 03-bluegreen/06-blue-green-demo-route.yaml"
  pe "cat 03-bluegreen/06-blue-green-demo-route.yaml | sed \"s/blue-green-demo-00001/$REV01/\" | sed \"s/blue-green-demo-00002/$REV02/\" | kubectl apply -f -"
  pe "curl -s --raw -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\" | grep class"
  pe "curl -s --raw -H \"Host: v1.${HOST_URL}\" \"http://${IP_ADDRESS}/\" | grep class"
  wait
  clear

  kubectl delete -f 03-bluegreen/ &>/dev/null
fi

### Demo 4
if [[ $DEMOS == *"4"* ]]; then
  title="Demo 4 - Knative Build"
  echo $title

  pe "cat 04-build/kaniko.yaml"
  pe "kubectl apply -f 04-build/kaniko.yaml"
  pe "cat 04-build/build.yaml"
  pe "kubectl apply -f 04-build/build.yaml"
  echo
  wait
  clear

  echo $title
  pe "kubectl get build"
  pe "kubectl get pod"
  echo "type export BUILDPOD=pod"
  cmd
  pe "kubectl -n default logs $BUILDPOD -c build-step-credential-initializer"
  pe "kubectl -n default logs $BUILDPOD -c build-step-git-source-0"
  pe "kubectl -n default logs $BUILDPOD -c build-step-build-and-push -f"

  echo "As this takes too long for demo: skip"

  kubectl delete -f 04-build/ &>/dev/null
fi

### Demo 5
if [[ $DEMOS == *"5"* ]]; then
  title="Demo 5 - Knative Eventing"
  echo $title

  pe "cat 05-eventing/eventing.yaml"
  pe "kubectl apply -f 05-eventing/eventing.yaml"
  wait
  clear

  pe "kubectl logs -l serving.knative.dev/service=message-dumper -c user-container"
  pe "kubectl logs -l serving.knative.dev/service=message-dumper -c user-container"

  wait
  clear

  kubectl delete -f 05-eventing/ &>/dev/null
fi

if $CLEANUP; then
  for i in * ; do
    if [ -d "$i" ]; then
      kubectl delete -f $i
    fi
  done
fi

# The End
echo "THE END"
pe "exit"


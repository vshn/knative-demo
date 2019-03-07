#!/usr/bin/env bash

# https://github.com/paxtonhare/demo-magic
. demo-magic.sh

# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

# the demo starts here
pe "kubectl get nodes"
wait
clear

# Demo 1 - Serving

pe "cat 01-helloworld/helloworld.yaml"
pe "kubectl apply -f 01-helloworld/helloworld.yaml"
wait
clear

export HOST_URL=$(kubectl -n default get ksvc helloworld-go --output jsonpath='{.status.domain}')
export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

pe "curl -H \"Host: ${HOST_URL}\" http://${IP_ADDRESS}/"
wait
clear

pe "kubectl -n default get route"
pe "kubectl -n default get revision"
pe "kubectl -n default get configuration"
pe "kubectl -n default edit ksvc helloworld-go"
pe "curl -H \"Host: ${HOST_URL}\" http://${IP_ADDRESS}/"

# The End
p "# Thanks for watching"


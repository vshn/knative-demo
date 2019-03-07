# Knative Demo

This project contains demo files for giving a Knative demo to interested parties.

## Prerequisits

* A fresh Kubernetes cluster (1.11+) with cluster-admin rights
* Knative installed as described in the [official docs](https://github.com/knative/docs/blob/master/install/Knative-with-any-k8s.md)
  * Installed with Istio

### Adaption: Ingressgateway service type

If the K8s cluster doesn't support services with the type `LoadBalancer`, change it to be `NodePort`:

```
kubectl -n istio-system patch svc istio-ingressgateway -p '{"spec":{"type": "NodePort"}}
```

### Adaption: Custom domain

By default the domain `example.com` is used. To change that, edit the corresponding configmap:

```
kubectl -n knative-serving edit cm config-domain
```

# Demo 1: Hello World

This manifest deploys a hello world application to showcase the `serving` component.

```
kubectl apply -f 01-helloworld/helloworld.yaml
```

Access the service using the following commands:

```
export HOST_URL=$(kubectl -n default get ksvc helloworld-go --output jsonpath='{.status.domain}')
export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

curl -H "Host: ${HOST_URL}" http://${IP_ADDRESS}
```

Interesting parts:
* Pod gets scaled down automatically when not in use after ...
* Many objects get automatically created by the `Service` object:
  * **Route**: provides a named endpoint and a mechanism for routing traffic to: `kubectl -n default get route`
  * **Revisions**: immutable snapshots of code + config: `kubectl -n default get revision`
  * **Configuration**: acts as a stream of environments for Revisions: `kubectl -n default get configuration`
  * See graphic: https://github.com/knative/serving/blob/master/docs/spec/overview.md#resource-types

Editing the service using `kubectl -n default edit ksvc helloworld-go` creates a new revision.

# Demo 2: Autoscaling

Deploy the sample application using:

```
kubectl apply -f 02-autoscaling/autoscale.yaml
```

Access the service using the following commands:

```
export HOST_URL=$(kubectl -n default get ksvc autoscale-go --output jsonpath='{.status.domain}')
export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

curl -H "Host: ${HOST_URL}" "http://${IP_ADDRESS}?sleep=100&prime=10000&bloat=5"
```

Install the `hey` load generator (`go get -u github.com/rakyll/hey`) and generate some load:

```
hey -z 30s -c 50 \
  -host "${HOST_URL}" \
  "http://${IP_ADDRESS?}?sleep=100&prime=10000&bloat=5" &
watch kubectl get po
```

What happens here is described under [Algorithm](https://github.com/knative/docs/tree/master/serving/samples/autoscale-go#algorithm)

Interesting metrics can be found in Grafana dashboards:

* [Knative Serving - Scaling Debugging](http://localhost:3000/d/u_-9SIMiz/knative-serving-scaling-debugging?orgId=1&refresh=5s&from=now-15m&to=now)
* [Knative Serving - Revision HTTP Requests](http://localhost:3000/d/im_gFbWik/knative-serving-revision-http-requests?refresh=5s&orgId=1)

To access the Grafana Dashboard, start port-forwarding:

```
kubectl port-forward --namespace knative-monitoring \
$(kubectl get pods --namespace knative-monitoring \
--selector=app=grafana --output=jsonpath="{.items..metadata.name}") \
3000
```

# Demo 3: Build

This demo uses Kaniko, install a build template first:

```
kubectl apply -f https://raw.githubusercontent.com/knative/build-templates/master/kaniko/kaniko.yaml
```

TODO Prepare registry

Apply the manifest to start building and deploying the application:

```
kubectl apply -f 03-build/build.yaml
```

Build is now running in a Pod using init containers. To view logs, use:

```
kubectl -n default logs <buildpod> -c build-step-credential-initializer
kubectl -n default logs <buildpod> -c build-step-git-source-0
kubectl -n default logs <buildpod> -c build-step-build-and-push
```

# Demo 4: Eventing

Apply the manifest to define a service (sink) and an eventsource:

```
kubectl apply -f 04-eventing/eventing.yaml
```

```
kubectl logs -l serving.knative.dev/service=message-dumper -c user-container --since=10m
```

# TODO

* Write script using https://github.com/paxtonhare/demo-magic
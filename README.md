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

## Links

To get some insights before starting the demo, checkout the following links:

* [Knative Docs](https://github.com/knative/docs)
* [Serving Resource Types / Overview](https://github.com/knative/serving/blob/master/docs/spec/overview.md)
* [Eventing Introduction](https://github.com/knative/docs/blob/master/eventing/README.md)
* [Build Introduction](https://github.com/knative/docs/blob/master/build/README.md)

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

Status of autoscaler can be retrieved using:

```
kubectl get kpa
```

# Demo 3: Blue/Green Deployment

Deploy the initial blue deployment:

```
kubectl apply -f 03-bluegreen/01-blue-green-demo-config.yaml
```

Get name of the generated revision and write this name into the route object:

```
kubectl get revision -l serving.knative.dev/configuration=blue-green-demo
export REV01=<name>
cat 03-bluegreen/02-blue-green-demo-route.yaml | sed "s/blue-green-demo-00001/$REV01/" | kubectl apply -f -
```

Access the service:

```
export HOST_URL=blue-green-demo.default.example.com
export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

curl -H "Host: ${HOST_URL}" "http://${IP_ADDRESS}/"
```

Now change the configuration with updated parameters:

```
kubectl apply -f 03-bluegreen/03-blue-green-demo-config.yaml
```

Accessing the route will still serve the initial version, we can now update
the route to point to the new revision:

```
kubectl get revision -l serving.knative.dev/configuration=blue-green-demo
export REV02=<name>
cat 03-bluegreen/04-blue-green-demo-route.yaml | \
  sed "s/blue-green-demo-00001/$REV01/" | \
  sed "s/blue-green-demo-00002/$REV02/" | \
  kubectl apply -f -

curl -H "Host: v2.${HOST_URL}" "http://${IP_ADDRESS}/"
```

The new revision is now available under this new URL.

Let's send 50% of the requests to the new version:

```
cat 03-bluegreen/05-blue-green-demo-route.yaml | \
  sed "s/blue-green-demo-00001/$REV01/" | \
  sed "s/blue-green-demo-00002/$REV02/" | \
  kubectl apply -f -

watch -n1 "curl -H \"Host: ${HOST_URL}\" \"http://${IP_ADDRESS}/\" -s --raw"
```

The new version is still available under the v2 URL.

It's time to switch completely to v2, but let v1 accessible:

```
cat 03-bluegreen/06-blue-green-demo-route.yaml | \
  sed "s/blue-green-demo-00001/$REV01/" | \
  sed "s/blue-green-demo-00002/$REV02/" | \
  kubectl apply -f -

curl -H "Host: ${HOST_URL}" "http://${IP_ADDRESS}/"
curl -H "Host: v1.${HOST_URL}" "http://${IP_ADDRESS}/"
```

# Demo 4: Build

This demo uses Kaniko, install the build template first:

```
kubectl apply -f 04-build/kaniko.yaml
```

Access to a container registry needs to be configured. Amend the YAML file accordingly.
After that, apply the manifest to start building and deploying the application:

```
kubectl apply -f 04-build/build.yaml
```

Build is now running in a Pod using init containers. To view logs, use:

```
kubectl -n default logs <buildpod> -c build-step-credential-initializer
kubectl -n default logs <buildpod> -c build-step-git-source-0
kubectl -n default logs <buildpod> -c build-step-build-and-push
```

After the build has finished it's job, a deployment is made. The app can be reached under:

```
export HOST_URL=$(kubectl -n default get ksvc app-from-source --output jsonpath='{.status.domain}')
export IP_ADDRESS=$(kubectl get node -o 'jsonpath={.items[0].status.addresses[0].address}'):$(kubectl -n istio-system get svc istio-ingressgateway -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}')

curl -H "Host: ${HOST_URL}" "http://${IP_ADDRESS}/"
```

# Demo 5: Eventing

Apply the manifest to define a service (sink) and an eventsource:

```
kubectl apply -f 05-eventing/eventing.yaml
```

A `CronJobSource` is now deployed which creates an event every 2 minutes. The events are
catched by the sink app called message-dumper:

```
kubectl logs -l serving.knative.dev/service=message-dumper -c user-container --since=10m
```

# TODO

* Write script using https://github.com/paxtonhare/demo-magic
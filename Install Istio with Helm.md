# Install Istio

Create the istio namespace:

```ps
kubectl create namespace istio-system
```

Enter in the folder where we have the Istio installation:

```ps
cd istio-1.10.0
```

Run the helm charts:

```ps
helm install istio-base manifests/charts/base -n istio-system

helm install istiod manifests/charts/istio-control/istio-discovery -n istio-system

helm install istio-ingress manifests/charts/gateways/istio-ingress -n istio-system

helm install istio-egress manifests/charts/gateways/istio-egress -n istio-system
```

Configure the namespace for automatic injection:

```ps
kubectl label namespace default istio-injection=enabled
```

## Verifying the installation

```ps
kubectl get pods -n istio-system

NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7fcc5fc4c7-9rf72    1/1     Running   0          30m
istio-ingressgateway-8579cc48f8-svldt   1/1     Running   0          32m
istiod-6568f5f485-gtdjz                 1/1     Running   0          22m
```

## Update Deployment size

He modificado el `deployment` `ìstiod` para que los recursos que precisa de memoria sean más pequeños, y así poder usar el nodo más pequeño disponible en Azure. Estaba en 2GB:

```yaml
{
  "kind": "Deployment",
  "apiVersion": "extensions/v1beta1",
  "metadata": {
    "name": "istiod",
    "namespace": "istio-system",

...

            "resources": {
              "requests": {
                "cpu": "500m",
                "memory": "2GB"
              }
            },

...
```

Y lo he dejado en 500 MB:

```yaml
{
  "kind": "Deployment",
  "apiVersion": "extensions/v1beta1",
  "metadata": {
    "name": "istiod",
    "namespace": "istio-system",

...

            "resources": {
              "requests": {
                "cpu": "500m",
                "memory": "500Mi"
              }
            },

...
```


## Uninstall Istio

```ps
helm delete istio-egress -n istio-system

helm delete istio-ingress -n istio-system

helm delete istiod -n istio-system

helm delete istio-base -n istio-system

kubectl delete namespace istio-system
```

# Install Bookinfo

```ps
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

We can check if the instalation is ok:

```ps
kubectl get services

NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
details       ClusterIP   10.0.134.97    <none>        9080/TCP   15m
kubernetes    ClusterIP   10.0.0.1       <none>        443/TCP    3h6m
productpage   ClusterIP   10.0.134.138   <none>        9080/TCP   15m
ratings       ClusterIP   10.0.214.250   <none>        9080/TCP   15m
reviews       ClusterIP   10.0.5.213     <none>        9080/TCP   15m
```

```ps
kubectl get pods

NAME                              READY   STATUS    RESTARTS   AGE
details-v1-79f774bdb9-sx57p       2/2     Running   0          16m
productpage-v1-6b746f74dc-t7xzt   2/2     Running   0          15m
ratings-v1-b6994bb9-842tk         2/2     Running   0          16m
reviews-v1-545db77b95-96mpv       2/2     Running   0          16m
reviews-v2-7bf8c9648f-cl57x       2/2     Running   0          16m
reviews-v3-84779c7bbc-5kr8r       2/2     Running   0          16m
```

Notice that we have two containers for pod - one of the will be the sidecar. We will create the gateway and the egress for external access:

```ps
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

We verify the app:

```ps
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"

<title>Simple Bookstore App</title>
```

We can check whether everything is allright:

```ps
istioctl analyze

No validation issues found when analyzing namespace: default.
```

## Determining the ingress IP and ports

```sh
kubectl get svc istio-ingressgateway -n istio-system

NAME                   TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.0.195.25   20.82.62.186   15021:31777/TCP,80:32227/TCP,443:32514/TCP   38m
```

```sh
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
```

```sh
echo "$GATEWAY_URL"

20.82.62.186:80
```

```sh
echo "http://$GATEWAY_URL/productpage"

http://20.82.62.186:80/productpage
```

## Uninstall the Bookinfo app


# Dashboards

```ps
kubectl apply -f samples/addons


serviceaccount/grafana created
configmap/grafana created
service/grafana created
deployment.apps/grafana created
configmap/istio-grafana-dashboards created
configmap/istio-services-grafana-dashboards created
deployment.apps/jaeger created
service/tracing created
service/zipkin created
service/jaeger-collector created
customresourcedefinition.apiextensions.k8s.io/monitoringdashboards.monitoring.kiali.io created
serviceaccount/kiali created
configmap/kiali created
clusterrole.rbac.authorization.k8s.io/kiali-viewer created
clusterrole.rbac.authorization.k8s.io/kiali created
clusterrolebinding.rbac.authorization.k8s.io/kiali created
role.rbac.authorization.k8s.io/kiali-controlplane created
rolebinding.rbac.authorization.k8s.io/kiali-controlplane created
service/kiali created
deployment.apps/kiali created
serviceaccount/prometheus created
configmap/prometheus created
clusterrole.rbac.authorization.k8s.io/prometheus created
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
service/prometheus created
deployment.apps/prometheus created
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
unable to recognize "samples\\addons\\kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
```

```ps
kubectl rollout status deployment/kiali -n istio-system

Waiting for deployment "kiali" rollout to finish: 0 of 1 updated replicas are available...
deployment "kiali" successfully rolled out
```

Abrimos el dashboard de Kiali:

```ps
istioctl dashboard kiali
```

Vamos a enviar carga para ver el dashboard con datos:

```sh
for i in $(seq 1 100); do curl -s -o /dev/null "http://$GATEWAY_URL/productpage"; done
```
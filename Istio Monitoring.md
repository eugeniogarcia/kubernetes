## Install Istio

Descargar la última version de Istio. Con `istioctl` instalado, ejecutar:

```
istioctl manifest apply --set profile=demo
```

Nos aseguramos de que el namespace default inyecte los sidecars de istio automáticamente:

```sh
kubectl label namespace default istio-injection=enabled
```

__NOTA__: He modificado el `deployment` `ìstiod` para que los recursos que precisa de memoria sean más pequeños, y así poder usar el nodo más pequeño disponible en Azure. Estaba en 2GB:

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

## Install bookinfo

```sh
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
```

We enable distributed trazing with `Zipkin`, kpi monitoring with `Grafana` & `Prometheus`, and the graphing of the istion mesh with `Kiali`:

```sh
istioctl manifest apply --set values.grafana.enabled=true --set values.tracing.enabled=true --set values.tracing.provider=zipkin --set values.tracing.ingress.enabled=true --set values.kiali.enabled=true --set "values.kiali.dashboard.grafanaURL=http://grafana:3000"
```

We can monitor the cluster. First we are granting rights:

```sh
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```

Now we can open the dashboard:

```sh
az aks browse --resource-group miAKCluster --name miAKCluster
```

We can check if Prometheus & Grafana are ok:

```sh
kubectl -n istio-system get svc prometheus

kubectl -n istio-system get svc grafana
```

Lets generate some load. Lets see what is the ingress ip:

```sh
kubectl get svc istio-ingressgateway -n istio-system
```

Now we can generate the load:

```sh
watch -n 1 curl -o /dev/null -s -w %{http_code} http://40.66.58.159/productpage
```

Then we can open Grafana:

```sh
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000
```

and now `http://localhost:3000/dashboard/db/istio-mesh-dashboard`

To monitor the traces:

```sh
istioctl dashboard zipkin
```

And finally to watch Kiali (user and password are `admin`, `admin`):

```sh
istioctl dashboard kiali
```
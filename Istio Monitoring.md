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

## Setup Monitoring

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

### Kiali usuer

Por alguna razón, en la última versión de Istio el usuario password de Kiali no estaba seteado a `admin`, `admin`. Para especificar el usuario estos son los pasos que hay que seguir:

1. Creamos el secret:

```ps
kubectl create secret generic kiali -n istio-system --from-literal=username=admin --from-literal=passphrase=admin
```

2. Borramos el pod de Kiali

```ps
kubectl get po -n istio-system                                                                                           

NAME                                    READY   STATUS    RESTARTS   AGE
grafana-75745787f9-kq97v                1/1     Running   0          13m
istio-ingressgateway-5498c5f958-bdw4t   1/1     Running   0          46m
istio-tracing-9dc46fd77-dd6zk           1/1     Running   0          13m
istiod-64dfc948fb-hpvf6                 1/1     Running   0          26m
kiali-85dc7cdc48-bdhpx                  1/1     Running   0          18m
prometheus-9d69dd564-x2jpk              2/2     Running   0          71m
```

```ps
kubectl delete po kiali-85dc7cdc48-bdhpx -n istio-system                                                                 pod "kiali-85dc7cdc48-bdhpx" 

deleted
```

El pod se recreara automáticamente:

```ps
kubectl get po -n istio-system                                                                                           

NAME                                    READY   STATUS    RESTARTS   AGE
grafana-75745787f9-kq97v                1/1     Running   0          14m
istio-ingressgateway-5498c5f958-bdw4t   1/1     Running   0          47m
istio-tracing-9dc46fd77-dd6zk           1/1     Running   0          14m
istiod-64dfc948fb-hpvf6                 1/1     Running   0          26m
kiali-85dc7cdc48-d9sk8                  0/1     Running   0          14s
prometheus-9d69dd564-x2jpk              2/2     Running   0          72m
```

Y ya podemos entrar.

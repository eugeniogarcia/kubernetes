# Instalar kubeflow

## Setup Kubernetes Cluster

Vamos a instalar kubeflow en Azure. En primer lugar creamos un cluster de Kubernetes en azure. He creado un cluster llamado `mikbs` en un resource group llamado `kubernetes`.

Configuramos kubectl para utilizar el cluster. Primero hacemos login en Azure

```sh
az login
```

Configuramos `kubectl`:

```sh
az aks get-credentials -n mikbs -g kubernetes
```

## Install Istio

Descargar la última version de Istio. Con `istioctl` instalado, ejecutar:

```sh
istioctl manifest apply --set profile=demo --set values.grafana.enabled=true --set values.tracing.enabled=true --set values.tracing.provider=zipkin --set values.tracing.ingress.enabled=true --set values.kiali.enabled=true --set "values.kiali.dashboard.grafanaURL=http://grafana:3000"
```

We have enabled distributed tracing with `Zipkin`, kpi monitoring with `Grafana` & `Prometheus`, and the graphing of the istion mesh with `Kiali`.

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

### Install bookinfo

```sh
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
```

We can monitor the cluster. First we are granting rights:

```sh
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```

Now we can open the dashboard:

```sh
az aks browse --resource-group kubernetes --name mikbs
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
watch -n 1 curl -o /dev/null -s -w %{http_code} http://20.40.137.109/productpage
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

## Install KNative

Hay que elegir una versión de Knative que sea compatible con la versión de Kubernetes usada en el cluster. En mi caso es la 0.11.1 porque mi Kubernetes esta en versión 1.14

### KServing

```sh
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.11.1/serving-crds.yaml

kubectl apply --filename https://github.com/knative/serving/releases/download/v0.11.1/serving-core.yaml

kubectl apply --filename https://github.com/knative/serving/releases/download/v0.11.1/serving-istio.yaml
```

```
kubectl --namespace istio-system get service istio-ingressgateway


NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                                                                                                                                      AGE
istio-ingressgateway   LoadBalancer   10.0.217.205   20.40.137.109   15020:30577/TCP,80:32762/TCP,443:30805/TCP,15029:32654/TCP,15030:30454/TCP,15031:31340/TCP,15032:32225/TCP,31400:30931/TCP,15443:31254/TCP   4h22m
```

Podemos comprobar que KServing esta operativo:

```sh
kubectl get pods --namespace knative-serving


NAME                                READY   STATUS    RESTARTS   AGE
activator-5d9f8cbb57-2vnwm          2/2     Running   0          2m31s
autoscaler-759f45457b-vzjwv         2/2     Running   1          2m30s
autoscaler-hpa-5c55678ffd-fv9wb     1/1     Running   0          2m31s
controller-5c746f9cf7-zlp7t         1/1     Running   0          2m28s
networking-istio-5b48fbd6fb-2ssrb   1/1     Running   0          79s
webhook-864fcc4466-j9nkb            1/1     Running   0          2m27s
```

### KEventing

```sh
kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.11.0/eventing.yaml

kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.11.0/release.yaml
```

Instalamos un channel. Elijo el canal inMemory. Podría haber usado `Kafka`, o `Google Pub/Sub`:

```sh
kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.11.0/in-memory-channel.yaml
```

Podemos comprobar que KEventing esta operativo:

```sh
kubectl get pods --namespace knative-eventing


NAME                                   READY   STATUS    RESTARTS   AGE
eventing-controller-666b79d867-kl49n   1/1     Running   0          5m37s
eventing-webhook-5867c98d9b-dwkrq      1/1     Running   0          5m36s
imc-controller-7c4f9945d7-vg5xs        1/1     Running   0          5m8s
imc-dispatcher-7b55b86649-2r2zb        1/1     Running   0          5m8s
sources-controller-694f8df9c4-g2mxh    1/1     Running   0          5m37s
```

### Ejemplo (KServing)

Podemos ver los recursos knative como sigue:

```sh
kubectl get revision

kubectl get kservice

kubectl get route
```

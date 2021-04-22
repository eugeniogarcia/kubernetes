# Base

Vemos la definición base:

```ps
kubectl kustomize base
```

```ps
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: hue
    tier: internal-service
  name: hue-learner
spec:
  containers:
  - env:
    - name: DISCOVER_QUEUE
      value: dns
    - name: DISCOVER_STORE
      value: dns
    image: g1g1/hue-learn:0.3
    name: hue-learner
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
```

Esta definición se toma de `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
commonLabels:
  app: hue

resources:
  - hue-learn.yaml
```

En esencia los recursos que se construyen se especifican en _resources_, `hue-learn.yaml`  y se sobreponen las etiquetas definidas en `commonLabels`.

Si quisieramos aplicar este recurso haríamos:

```ps
kubectl -k base apply
```

# Overlays

En realidad la base no esta previsto que se aplique. Su misión es la de servir de, base. En la carpeta _overlays_ tenemos las variantes del recurso que queremos aplicar. Por ejemplo con este _Kustomization_ estamos tomando la base que hemos visto antes, le añadimos las etiquetas definidas en `commonLabels`, indicamos que el `namespace: staging`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: staging
commonLabels:
  environment: staging
bases:
- ../../base

patchesStrategicMerge:
  - hue-learn-patch.yaml

resources:
- namespace.yaml
```

Con `patchesStrategicMerge` especificamos si queremos cambiar algo del pod. Si vemos `hue-learn-patch.yaml`, lo que estamos diciendo es que se use la imagen `image: g1g1/hue-learn:0.4` en lugar de `image: g1g1/hue-learn:0.3`, que es lo que se definía en la base:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hue-learner
spec:
  containers:
  - name: hue-learner
    image: g1g1/hue-learn:0.4
```

Estamos también creando un namespace, gracias a la entrada `resources`:

```yaml
resources:
- namespace.yaml
```

## Recurso

Vemos el recurso:

```ps
kubectl kustomize .\overlays\staging\
```

```ps
apiVersion: v1
kind: Namespace
metadata:
  labels:
    environment: staging
  name: staging
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: hue
    environment: staging
    tier: internal-service
  name: hue-learner
  namespace: staging
spec:
  containers:
  - env:
    - name: DISCOVER_QUEUE
      value: dns
    - name: DISCOVER_STORE
      value: dns
    image: g1g1/hue-learn:0.4
    name: hue-learner
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
```

y lo aplicamos:

```ps
kubectl -k .\overlays\staging\ apply
```

Para producción:

```ps
kubectl kustomize .\overlays\production\
```

```ps
kubectl -k .\overlays\production\ apply
```
```ps
kubectl kustomize base

kubectl -k base apply

kubectl kustomize .\overlays\staging\

kubectl -k .\overlays\staging\ apply

kubectl kustomize .\overlays\production\

kubectl -k .\overlays\production\ apply
```

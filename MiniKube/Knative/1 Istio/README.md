Cuando instale Istio los sidecars no se injectaban automaticamente. Hice dos cosas para que se injectaran.  

1. En la linea de comandos para arrancar minikube habilitamos el plugin de admision "MutatingAdmissionWebhook":  

```
minikube start --memory=11264 --cpus=5 --vm-driver "hyperv" --hyperv-virtual-switch "ParaMiniKube" --disk-size=20g --extra-config=apiserver.enable-admission-plugins="LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook"
```

2. En el configmap "istio-sidecar-injector" del namespace "istio-system", en el json donde se define la politica, tuve que habilitarla explicitamente. si hacemos:  
```
kubectl -n istio-system get configmap istio-sidecar-injector -o jsonpath='{.data.config}' | grep policy:
```  

Nos tiene que retornar:  
```
policy: enabled
```

## Update
He actualizado en istio.yaml, de modo que ya no es identico al que descargue de github. ¿Que he cambiado?:  
- He cambiado el configmap para que la policy de inyectar contenedores este habilitada por defecto (lo que comentaba en el punto anterior)
- El Horizontal Autoscaler para que el minimo de pods de Istio sea 1 en lugar de tres
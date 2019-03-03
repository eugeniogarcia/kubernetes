
Ver la [página](https://microk8s.io/) de microk8s.    
# Instalación
Se instala con snap:  
```
sudo snap install microk8s --classic
sudo snap install microk8s --edge --classic
```
Los Snaps se publican en canales que consisten de un track (o major version), y un nivel de estabilidad. Podemos ver las versiones publicadas:  
```
snap info microk8s
```
Si queremos seleccionar una - bien la ultima, o una concreta:  
```
snap refresh --channel=latest/beta microk8s
snap refresh --channel=1.11/stable microk8s
```
# Primeros pasos
Podemos empezar a usarlo:
```
microk8s.kubectl get nodes
```
Podemos arrancar y parar el servicio:  
```
microk8s.start
microk8s.stop
```
Sino queremos poner el prefijo de microk8s:  
```
snap alias microk8s.kubectl kubectl
```
## Addons
Pomdemos habilitar varios add-ons:  
```
microk8s.enable addon1 addon2
```
Entre los addons disponibles destacamos:  

- dns: para desplegar kube dns, es requerido por otros addons así que siempre se aconseja habilitarlo.  
- dashboard: con este addon tenemos disponible el típico dashboard de Kubernetes y los gráficos con Grafana.  
- storage: para permitir la creación de volúmenes persistentes.  
- ingress: para poder hacer redirecciones y balanceos en local.    
- istio: para desplegar los servicios de Istio. Todo el manejo de los comandos de Istio se hace con microk8s.istioctl  
- registry: para habilitar un registro privado de Docker al que poder acceder desde localhost:32000 que se maneja con el comando microk8s.docker  

### Resetea la Instalación
```
microk8s.reset
```

## Demo
```
microk8s.kubectl get all --all-namespaces

microk8s.kubectl get no

microk8s.enable dns dashboard

watch microk8s.kubectl get all --all-namespaces

microk8s.kubectl run nginx --image nginx --replicas 3

watch microk8s.kubectl get all --all-namespaces

microk8s.kubectl expose deployment nginx --port 80 --target-port 80 --type ClusterIP --selector=run=nginx --name=eugenio

watch microk8s.kubectl get all

microk8s.kubectl delete deployment/nginx

microk8s.kubectl delete svc/eugenio

microk8s.disable dashboard dns

sudo snap remove microk8s
```

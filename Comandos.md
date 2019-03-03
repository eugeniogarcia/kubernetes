# Primeros pasos
Crea un pod con un replication controller, en lugar de con un Deployment. Esto se logra gracias a que hemos usado --generator al final del comando:  
```
kubectl run hola --image=egsmartin/hola --port=8080 --generator=run/v1
```
Vemos los pods:  
```
kubectl get pods
kubectl get pods -o wide
kubectl get po --show-labels
kubectl get po --namespace kube-system
kubectl describe pod hola
```
Y creamos un servicio que expondra al pod fuera de nuestro cluster:  
```
kubectl expose rc hola --type=LoadBalancer --name hola-http
```
Vemos los servicios. Podremos ver la ip del cluster y la externa - porque es de tipo loadbalancer:  
```
kubectl get services
```
Vemos los replication controllers:  
```
kubectl get replicationcontrollers
kubectl get rc
```
Podemos escalar horizontalmente:  
```
kubectl scale rc hola --replicas=3
```
Podemos ver el dashboard disponible en el plano de control:  
```
kubectl cluster-info | grep dashboard
minikube dashboard
```
# Pods
Obtener el yaml que describe a un pod:  
```
kubectl get po hola -o yaml
```
Podremos ver:  
- Kind: tipo de recurso; En este caso es un Pod  
- Metadata: Podemos ver el namespace - casi siempre sera default -, las Annotations y las labels  
- Spec: Definicion de los contenedor(es) que definen el pod. Para cada contenedor tendremos la imagen, nombre, puertos, variables de entorno, volumnes, argumentos, ...  

Podemos crear el Pod en base a un yaml:  

```
kubectl create -f egsmartin-manual.yaml
```
## Ver Logs
De forma similar a como podemos ver logs en un contenedor de Docket, podremos también acceder a los logs de un Pod. Si el Pod tiene más de un contenedor, podremos especificar de que contenedor queremos los logs con la opción -c:  
```
docker logs <container id>
kubectl logs hola-manual
kubectl logs hola-manual -c hola
```
## Mapear un Pod a un puerto
Podemos mapear alguno de los puertos del pod de la siguiente forma:  
```
kubectl port-forward hola-manual 8888:8080
```
## Etiquetas
```
kubectl get po --show-labels
kubectl get po -L creation_method,env
```
Crea o modifica una etiqueta de Un Pod. Para modificar un valor existente hay que usar la opción overwrite:  
```
kubectl label po hola-manual mi_etiqueta=mi_valor
kubectl label po hola-manual mi_etiqueta=mi_valor --overwrite
```
### Buscar con etiqueta
Obtiene los Pods que tienen la etiqueta env, o que no la tienen:  
```
kubectl get po -l env
kubectl get po -l '!env'
```
### Schedule un Pod usando Etiquetas
Podemos asignar etiquetas a los nodos:  
```
kubectl get node
kubectl label node gke-kubia-85f6-node-0rrx gpu=true
kubectl get nodes -l gpu=true
```
Una vez tenemos etiquetados los nodos, en la especificación del Pod podemos indicar que condiciones tiene que cumplier el nodo, que etiquetas tiene que tener:  
```
apiVersion: v1
kind: Pod
metadata:
  name: kubia-gpu
spec:
  nodeSelector:
    gpu: "true"
  containers:
  - image: luksa/kubia
    name: kubia
```
## Anotaciones
Las anotaciones sirven para asociar metadatos a los recuersos. No se emplean para el scheduling. Podemos especificar una anotacion:  
```
kubectl annotate pod hola-manual mycompany.com/someannotation="foo bar"
```
## Namespaces
Recuperamos los namespaces definidos en el cluster:  
```
kubectl get ns
```
Podemos buscar cualquier recurso usando como criterio el namespace. Por ejemplo, la lista de Pods de un determinado namespace:  
```
kubectl get po --namespace kube-system
```
### Crea un namespace
Podemos crear un namespace con un yaml:  
```
apiVersion: v1
kind: Namespace
metadata:
  name: custom-namespace
```
```
kubectl create -f custom-namespace.yaml
```
También se puede crear con la línea de comandos:  
```
kubectl create namespace custom-namespace
```
Al crear un objeto podemos especificar el namespace:  
```
kubectl create -f hola-manual.yaml -n custom-namespace
```
### Borrar un Namespace
Cuando se borra un namespace se borran todos los objetos que contiene (Pods, RC, etc):  
```
kubectl delete ns custom-namespace
```

## Borrar Pods
Podemos borrar Pods especificando su nombre, o una etiqueta - borraría todos los Pods que tengan la etiqueta:  
```
kubectl delete po kubia-gpu
kubectl delete po -l creation_method=manual
```
Podemos borrar todos los Pods del namespace por defecto:  
```
kubectl delete po --all
```
De echo podemos borrar todos los objetos de un namespace:  
```
kubectl delete all --all
```

## Consulta Pods
Varios criterios para consultar los Pods creados. Podemos sacar información adicional usando ```-o wide```. Podemos especificar el namespace en el que buscar. Podemos indicar que se muestren las etiquetas:  
```
kubectl get pods
kubectl get pods -o wide
kubectl get po --show-labels
kubectl get po --namespace kube-system
kubectl describe pod hola
```
# Replication Controllers
## Liveness Probes
Podemos indicar en la especificación de un Pod un criterio de liveness. Con este propiedad le estamos indicando a Kubernetes como determinar si el contenedor esta o no vivo. Se puede definir de varias formas:  
- ***http get probe***:  Kubernetes hara una get via http y si la respuesta es un 2xx o un 3xx, el contenedor se considera vivo  
- ***TCP socket probe***: Se establece una conexión con un socket. Si se puede hacer la conexión, el contenedor esta vivo    
- ***Exec probe***:  Se ejecuta un comando - cualquiera - en el contenedor, y el exit code determinara si el contenedor esta o no vivo  
En este yaml estamos definiendo una probe http get:  

```
apiVersion: v1
kind: pod
metadata:
  name: kubia-liveness
spec:
  containers:
  - image: luksa/kubia-unhealthy       
    name: kubia
    livenessProbe:                     
      httpGet:                         
        path: /                        
        port: 8080                     
```
Podemos ver el liveness probe en acción:  
```
kubectl get po kubia-liveness
```
Si queremos ver el log del contenedor que ha matado Kubernetes:  
```
kubectl logs mypod --previous
```
Podemos configurar un tiempo para que Kubernetes empiece a chequear el liveness:  
```
apiVersion: v1
kind: pod
metadata:
  name: kubia-liveness
spec:
  containers:
  - image: luksa/kubia-unhealthy       
    name: kubia
    livenessProbe:                     
      httpGet:                         
        path: /                        
        port: 8080
      initialDelaySeconds: 15                     
```
Kubernetes esperara 15 segundos antes de lanzar le primera sonda.  
## Replication Controlers  
Un Replication Controler consta de tres partes principales:  
- Etiquetas. Determina que Pods va a controlar  
- Replica count. Número de Pods que deben ejecutarse  
- Template. Define la especificación del Pod cuando se tienen que crear nuevas replicas  

```
apiVersion: v1
kind: ReplicationController        
metadata:
  name: kubia                      
spec:
  replicas: 3                      
  selector:                        
    app: kubia                     
  template:                        
    metadata:                      
      labels:                      
        app: kubia                 
    spec:                          
      containers:                  
      - name: kubia                
        image: luksa/kubia         
        ports:                     
        - containerPort: 8080      
```
Podemos crear el Replication Controller:  
```
kubectl create -f kubia-rc.yaml
```
Esto hara que los Pods se empiecen a crear. Si borrasemos un Pod el Replication Controller arrancara otro Pod.  

```
kubectl get pods

NAME          READY     STATUS              RESTARTS   AGE
kubia-53thy   0/1       ContainerCreating   0          2s
kubia-k0xz6   0/1       ContainerCreating   0          2s
kubia-q3vkg   0/1       ContainerCreating   0          2s
```
Los Pods se estan creando. Si esperamos un poco se habrán creado todos. Si eliminamos uno, el Replication Controller arrancara uno nuevo:  
```
kubectl delete pod kubia-53thy

kubectl get pods

NAME          READY     STATUS              RESTARTS   AGE
kubia-53thy   1/1       Terminating         0          3m
kubia-oini2   0/1       ContainerCreating   0          2s
kubia-k0xz6   1/1       Running             0          3m
kubia-q3vkg   1/1       Running             0          3m
```
Comprobemos el estado del Replication Controller:  
```
kubectl get rc

NAME      DESIRED   CURRENT   READY     AGE
kubia     3         3         2         3m

```
Podemos ver una descripción del Replication Controller:  
```
kubectl describe rc kubia
```
### Editar el yaml de un recuerso
Podemos cambiar la definición de un recurso con el comando edit. Antes de hacerlo hay que hacer alguna configuración, especificar en la variable de entorno donde encontrar el editor, en el ejemplo, nano:    
```
export KUBE_EDITOR="/usr/bin/nano"

kubectl edit rc kubia
```
## Horizontal Scaling
```
kubectl scale rc kubia --replicas=10
```
## Borrar
Cuando se borra un rc se borraran todos los Pods asociados. Si no queremos que eso suceda, hay que especificar ``-cascade=false``:   
```
kubectl delete rc kubia --cascade=false
```
# Replication Sets
No es parte de la versión 1.0 de la api, pero por lo demas se parecen mucho a un Replication Controller:  
```
apiVersion: apps/v1beta2            
kind: ReplicaSet                    
metadata:
  name: kubia
spec:
  replicas: 3
  selector:
    matchLabels:                    
      app: kubia                    
  template:                         
    metadata:                       
      labels:                       
        app: kubia                  
    spec:                           
      containers:                   
      - name: kubia                 
        image: luksa/kubia          
```
## Version
La propiedad tiene dos partes:  
- The API group. apps en este caso  
- La version. v1beta2 en este caso  

Algunos recursos pertenece al core API group. Para estos recursos no hace falta especificar la propiedad apiVersion. Para otros recursos que se han creado en versiones posteriores de Kubernetes, si hay que especificar la versión de la API.  
## Selección de pods
Con el Resource Set tenemos un mayor control sobre los Pods que se controlan que con los Resource Controlers.  Podemos especificar un selector:  
```
selector:
  matchExpressions:
    - key: app                      
      operator: In                  
      values:                       
        - kubia                     
```
Podemos especificar en el selector varios operadores:  
- ***In—Label’s*** la etiqueta debe tener un valor que este entr los especificados  
- ***NotIn—Label’s*** la etiqueta no debe coincidir con ninguna de las especificadas  
- ***Exists—Pod*** debe incluir una etiqueta entre las especificadas. No hay que informar el campo values  
- ***DoesNotExist—Pod*** No debe incluir una etiqueta entre las informadas. La propiedad values no se tiene que informar  

# Daemonsets
No se schedulena. Se ejecutara un Pod exactamente en cada nodo.  
```
apiVersion: apps/v1beta2           
kind: DaemonSet                    
metadata:
  name: ssd-monitor
spec:
  selector:
    matchLabels:
      app: ssd-monitor
  template:
    metadata:
      labels:
        app: ssd-monitor
    spec:
      nodeSelector:                
        disk: ssd                  
      containers:
      - name: main
        image: luksa/ssd-monitor
```

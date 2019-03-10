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
Cuando necesitamos que se ejecute un Pod en cada nodo, Daemonsets es la solución. Este recurso no se schedulea. Cuado un nodo se elimine, o un nodo se añada, se creara el correspondiente demonio.  
En el Deamonset podemos especificar un selector de nodos, de modo que podemos ontrolar sobre que nodos se aplicara el demonio. Por ejemplo, aqui solo consideramos nodos que tengan la etiqueta disk: ssd:   
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

En la definición podemos apreciar que ademas del selector tenemos un template. En el template declaramos los contenedores que constituyen el demonio.  

Creamos el recurso de la forma estandard:  
```
kubectl create -f ssd-monitor-daemonset.yaml

kubectl get ds

kubectl get node

kubectl label node minikube disk=ssd

kubectl label node minikube disk=hdd --overwrite

```
# Jobs
Los pods scheduleados con Resource Controllers, REsourcesets o Daemonsets tienen en comun que se ejecutan de forma initerrumpida. Si necesitamos ejecutar una tarea de forma puntual el recurso a utilizar es el Job.  
```
apiVersion: batch/v1                  
kind: Job                             
metadata:
  name: batch-job
spec:                                 
  template:
    metadata:
      labels:                         
        app: batch-job                
    spec:
      restartPolicy: OnFailure        
      containers:
      - name: main
        image: luksa/batch-job
```
En el yaml del job podemos apreciar el template, que incluye los metadatos con las etiquetas, y la specificación en ``spec``. La especificación incluye el contenedor a ejecutar y la política de ejecución. Podemos ver los jobs con:  
```
kubectl get jobs

```
Podemos ver los pods como siempre. Solo un matiz, el pod dejara de ejecutarse cuando el job termine. Si queremos ver los pods terminados tenemos que añadir `` --show-all o -a``. El pod no se borra cuando el job termina, pero cambia su estado. Al no haberse borrado, podremos ver su log de ejecución:  
```
kubectl get po -a

kubectl logs batch-job-28qf4
```
Podemos ver los jobs:  
```
kubectl get job
```
## Ejecución secuencial
Si necesitamos ejecutar varias vece un job, una detras de otra:  
```
apiVersion: batch/v1
kind: Job
metadata:
  name: multi-completion-batch-job
spec:
  completions: 5
  template:
    ....
```
En la spec especificamos que se necesita realizar cinco ejecuciones.  
## Ejecución en paralelo
```
apiVersion: batch/v1
kind: Job
metadata:
  name: multi-completion-batch-job
spec:
  completions: 5
  parallelism: 2
  template:
    ...
```
Estamos diciendo que se pueden ejecutar dos jobs en paralelo. Esto significa que como hay que hacer cinco ejecuciones, se precisaran tres ciclos para terminar de ejecutar todos los jobs.  
Podemos cambiar el grado de paralelismo con al propiead replicas:  
```
kubectl scale job multi-completion-batch-job --replicas 3
```
## Limitar el tiempo de ejecución de un Pod
Podemos especificar el tiempo que tendra un job para ejecutarse por medio de la propiedad ``activeDeadlineSeconds`` en la spec del Pod. Si la ejecución supera este tiempo, Kubernetes tratara de matar el Pod.
## Schedule un Job
Podemos crear un cronJob:  
```
apiVersion: batch/v1beta1                  
kind: CronJob
metadata:
  name: batch-job-every-fifteen-minutes
spec:
  schedule: "0,15,30,45 * * * *"           
  jobTemplate:
    spec:
      template:                            
        metadata:                          
          labels:                          
            app: periodic-batch-job        
        spec:                              
          restartPolicy: OnFailure         
          containers:                      
          - name: main                     
            image: luksa/batch-job         
```
En la spec del cronJob estamos indicando la programación - con una expresión cron - y el template. En este ejemplo el job se ejecutar en los minutos 0, 15, 30 y 45 de cada hora.  
Lo que sucedera es que el cronJob creara recursos de tipo Job, que a su vez crearan los Pods.  
```
apiVersion: batch/v1beta1                  
kind: CronJob
metadata:
  name: batch-job-every-fifteen-minutes
spec:
  schedule: "0,15,30,45 * * * *"           
  startingDeadlineSeconds: 15
  jobTemplate:
    spec:
      template:                            
        metadata:                          
          labels:                          
            app: periodic-batch-job        
        spec:                              
          restartPolicy: OnFailure         
          containers:                      
          - name: main                     
            image: luksa/batch-job         
```
En este ejemplo estamos indicando que el job debe empezar a ejecutarse 15 segundos después del instante programado.  
# Servicios
Podemos definir un servicio con el siguiente yaml:
```
apiVersion: v1
kind: Service
metadata:
  name: kubia
spec:
  ports:
  - port: 80                
    targetPort: 8080        
  selector:                 
    app: kubia              
```
Lo que estamos haciendo es crear un servicio que se expondra en el puerto 80 y que se conectara con los Pods que tengan como etiqueta app:Kubia, por medio del puerto 8080.  
```
kubectl get svc

NAME         CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
kubia        10.111.249.153   <none>        80/TCP    6m        
```
Este servicio solo sera accesible desde el cluster. Por ejemplo, desde cualquier contenedor del cluster podríamos hacer:  
```
kubectl exec kubia-7nog1 -- curl -s http://10.111.249.153
```
Lo que se indica despues de ``--`` en el comando es la instrucción que se ejecutar dentro  del contenedor.  
## Session Afinity
Podemos definir la afinidad del servicio. Hay dos posibles opciones:  
- None. Ninguna. Es el valor por defecto  
- ClienIP. Afinidad con la IP  
```
apiVersion: v1
kind: Service
spec:
  sessionAffinity: ClientIP
  ...
```

## Named ports
Si en lugar de hardcodear el puerto definimos en el Pod un named port, podremos referirnos a él por nombre en la definición del servicio. Por ejemplo, en este Pod:  
```
kind: Pod
spec:
  containers:
  - name: kubia
    ports:
    - name: http               
      containerPort: 8080      
    - name: https              
      containerPort: 8443      
```
Hemos definido dos named ports. Ahora en la definición del servicio podemos usarlos:  
```
apiVersion: v1
kind: Service
spec:
  ports:
  - name: http              
    port: 80                
    targetPort: http        
  - name: https             
    port: 443               
    targetPort: https       
```
Observese como el target port es una etiqueta, no un número.  
## Service Discovery
Podemos descubrir los servicios de dos formas diferentes:  
- Usando variables de entorno  
- Usando el DNS interno  

### Variables de entorno
Al crear un servicio se crean sendas variables de entorno para indicar la IP y el puerto del servicio. Estas variables de entorno estaran disponibles en los Pods - siempre y cuando el Pod se haya creado despues de haber creado el servicio; Si el Pod se hubiera creado antes del servicio, si borrasemos el Pod, cuando sea recreado por el controlador, las variables de entorno ya estaran disponibles.  
```
kubectl exec kubia-3inly env

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=kubia-3inly
KUBERNETES_SERVICE_HOST=10.111.240.1
KUBERNETES_SERVICE_PORT=443
...
```
### DNS
Podremos usar el FQDN para referirnos a un servicio:  
```
backend-database.default.svc.cluster.local
```
Aqui ``backend-database`` es el nombre del servicio, y el resto se corresponde con el dominio asociado al cluster. Esto significa que si dentro de un Pod quisieramos invocar al servicio, podríamos hacer:  
```
curl http://kubia.default.svc.cluster.local
```
Podemos omitir el dominio, porque Kubernetes configurara el ``hosts`` file de cada contendor:  
```
curl http://kubia

cat /etc/resolv.conf

search default.svc.cluster.local svc.cluster.local cluster.local ...

```
## Conectarse con Servicios fuera del Cluster  
Los servicios no se vinculan directamente a los Pods, hay un recurso entre medias, el Endpoint:
```
kubectl describe svc kubia


Name:                kubia
Namespace:           default
Labels:              <none>
Selector:            app=kubia                                          
Type:                ClusterIP
IP:                  10.111.249.153
Port:                <unset> 80/TCP
Endpoints:           10.108.1.4:8080,10.108.2.5:8080,10.108.2.6:8080    
Session Affinity:    None
```

En este caso vemos que el recurso Endpoint contiene una relación de IPs, so las IPs que exponen los Pods. Las IPs aqui listadas se crean dínamicamente en funcion del selector especificado. El proxy service eligira una de estas IPs para conectarse con los Pods.  
Si quisieramos hacer esto manualmente, tendriamos que crear el recurso Servicio y el recurso Endpoint.  El servicio lo creamos sin ningún selector:  
```
apiVersion: v1
kind: Service
metadata:
  name: external-service          
spec:                             
  ports:
  - port: 80
```
Este servicio aceptara peticiones en el puerto 80. Tendremos que crear un Endpoint resource con el ___mismo nombre que el servicio___:  
```
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service      
subsets:
  - addresses:
    - ip: 11.11.11.11         
    - ip: 22.22.22.22         
    ports:
    - port: 80                
```
Nótese como el nombre de los dos recursos es el mismo. El efecto sera que cuando se se dirijan peticiones al servicio, el servicio las redijira a una de las dos IPs especificadas en el Endpoint.  
Al crear el servicio manualmente tambien se crean las variables de entorno, como en cualquier servicio. Los tipos que podemos elegir al crear el servicio son los de siempre, ___ClusterIP___ y ___ClientIP___.  
### Más de un puerto
Podemos exponer el servicio atraves de más un puerto, y mapear el puerto a otro en el Pod:  
```
apiVersion: v1
kind: Service
metadata:
  name: kubia
spec:
  ports:
  - name: http              
    port: 80                
    targetPort: 8080        
  - name: https             
    port: 443               
    targetPort: 8443        
  selector:                 
    app: kubia              
```
Aquí estariamos exponiendo los puertos 80 y 443 en el servicio, y Kubernetes estaría dirigiendo las peticiones a los puertos 8080 y 8443 del Pod.  
### Crear un alias para los servicio externos
Al definir el servicio, en la definición del Endpoint podemos especifcar un fqdn en lugar de referirnos a las IPs:  
```
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  type: ExternalName                         1
  externalName: someapi.somecompany.com      2
  ports:
  - port: 80
```
Este servicio estaría apuntando a un servicio externo - en lugar de a un Pod.  
## Exponer Servicios fuera del Cluster
Hay tres formas de exponer los servicios a terceros:  
- ___NodePort___. En cada nodo se define un puerto que estara mapeado al servicio.  
- ___LoadBalancer___.  El servicio es expuesto através de un balancedor de carga dedicado, expuesto en una dirección IP pública.  
- ___Ingress service___. En lugar de crear un Balanceador de carga para cada recurso con su propia IP, el Ingress Service expondrá todos los servicios del Cluster que necesitamos. Un solo recurso expone todos los servicios.  

### Node Port
Especificamos en la spec que el tipo es NodePort, e indicamos el puerto que se tiene que abrir en cada nodo, en este caso 30123, el target Port y el puerto.
```
apiVersion: v1
kind: Service
metadata:
  name: kubia-nodeport
spec:
  type: NodePort             
  ports:
  - port: 80                 
    targetPort: 8080         
    nodePort: 30123          
  selector:
    app: kubia
```
Podemos ver la información del servicio:  
```
$ kubectl get svc kubia-nodeport

NAME             CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
kubia-nodeport   10.111.254.223   <nodes>       80:30123/TCP   2m
```

El servicio estara accessible en:  
- 10.11.254.223:80  
- IP del primer nodo:30123  
- IP del segundo nodo:30123  
- etc ...  

Es decir, se puede acceder el servicio desde el propio cluster tal y como hemos descrito en las secciones anteriores, pero tambien es posible acceder al servicio desde el exterior, utilizando la IP del nodo. Cuando nos dirigimos al puerto indicado en cualquiera de los nodos, el servicio es ejecutado.  
Nótese  que el external IP no esta informado.  
### LoadBalancer
```
apiVersion: v1
kind: Service
metadata:
  name: kubia-loadbalancer
spec:
  type: LoadBalancer                
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: kubia
```
Con esta opción se creara un Balanceador de carga que se expondrá en una IP pública:  
```
kubectl get svc kubia-loadbalancer

NAME                 CLUSTER-IP       EXTERNAL-IP      PORT(S)         AGE
kubia-loadbalancer   10.111.241.153   130.211.53.173   80:32143/TCP    1m
```
Vemos como hay una IP asignada. Podriamos encontrar el balanceador en:  
```
curl http://130.211.53.173
```
El balanceador distribuira las peticiones entre los nodos, dirigiendolas a la IP del nodo y el puerto 32143.  
Notese que en este caso no especificamos el perto del nodo en la especificación del servicio. Kubernetes selecciona un nodo al azar.  
#### Additional hops
Podemos hacer que una vez que las peticiones han sido dirigidas a un nodo determinado, subsecuentes peticiones que se tengan que hacer desde el servicio sean dirigidas al propio nodo:
```
spec:
  externalTrafficPolicy: Local
  ...
```
### Ingress service
El ingress service hay que habilitarlo:  
```
minikube addons list
- default-storageclass: enabled
- kube-dns: enabled
- heapster: disabled
- ingress: disabled                
- registry-creds: disabled
- addon-manager: enabled
- dashboard: enabled
```
El servicio de ingress no esta habilitado. Lo tenemos que habilitar:  
```
minikube addons enable ingress
```
El servicio ingress se habilita como un Pod más, pero dentro del namespace de Kubernetes:  
```
kubectl get po --all-namespaces

NAMESPACE    NAME                            READY  STATUS    RESTARTS AGE
default      kubia-rsv5m                     1/1    Running   0        13h
default      kubia-fe4ad                     1/1    Running   0        13h
default      kubia-ke823                     1/1    Running   0        13h
kube-system  nginx-ingress-controller-gdts0  1/1    Running   0        18m
```
Una vez el servicio esta habilitado podemos crear recursos para ingress:  
```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kubia
spec:
  rules:
  - host: kubia.example.com               
    http:
      paths:
      - path: /                           
        backend:
          serviceName: kubia-nodeport     
          servicePort: 80                 
```
Aqui estamos creando una lista de paths a los que se podrán acceder por medio de ``http://kubia.example.com``:  

```
kubectl get ingresses

NAME      HOSTS               ADDRESS          PORTS     AGE
kubia     kubia.example.com   192.168.99.100   80        29m
```
Aqui el ingress service se ha mapeado al path root, pero podriamos:
```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kubia
spec:
  rules:
  - host: kubia.example.com
      http:
        paths:
        - path: /kubia                
          backend:                    
            serviceName: kubia        
            servicePort: 80           
        - path: /foo                  
          backend:                    
            serviceName: bar          
            servicePort: 80           
```
Ahora estamos exponiendo dos path resources en el ingress, que apuntan a dos servicios diferentes, utilizando el puerto 80:  
- kubia.example.com/Kubia. Dirige las peticiones al servicio kubia  
- kubia.example.com/foo. Dirige las peticiones al servicio bar  

Otra opcion seria la de definir varios hostnames en el servicio ingress:  
```
spec:
  rules:
  - host: foo.example.com          
    http:
      paths:
      - path: /
        backend:
          serviceName: foo         
          servicePort: 80
  - host: bar.example.com          
    http:
      paths:
      - path: /
        backend:
          serviceName: bar         
          servicePort: 80
```  

Ahora estamos exponiendo dos path resources en el ingress, que apuntan a dos servicios diferentes, utilizando el puerto 80:  
- foo.example.com/. Dirige las peticiones al servicio kubia  
- bar.example.com/. Dirige las peticiones al servicio bar  

## Detefinir cuando un Pod estara listo - readiness probes- para recibir peticiones
Podemos definir una sonda en los Pods que determine cuando el Pod esta listo para recibir peticiones. Que no este listo no implicara que Kubernetes lo mate - como sucede con los liveness probes. La sonda se puede definir de tres formas diferentes:  
- ___Exec probe___. Se ejecuta un proceso dentro del Pod, y dependiendo del exit status, Kubernetes sabra si el Pod esta o no listo para recibir peticiones.    
- ___HTTP GET probe___. Kubernetes hara una peticion http. Si el Pod responde con un 200 sera señal de que esta disponible.  
- ___TCP Socket probe___. Se abre una conexión TCP con el puerto especificado del contenedor. Si la conexi'on se abre, siginifica que el contenedor esta listo.   

Kubernetes podra esperar durante un tiempo preestablecido para realizar la primera comprobación, de modo que si se precisa algun start-up se haga. Despues Kubernetes hara invocaciones períodicas para comprobar que el contendor siga disponible.  
```
apiVersion: v1
kind: ReplicationController
...
spec:
  ...
  template:
    ...
    spec:
      containers:
      - name: kubia
        image: luksa/kubia
        readinessProbe:           
          exec:                   
            command:              
            - ls                  
            - /var/ready          
        ...
```
La sonda se comprueba períodicamente, por defecto, cada 10 segundos.  

### Observar el estado de readiness

```
kubectl get po

NAME          READY     STATUS    RESTARTS   AGE
kubia-2r1qb   0/1       Running   0          1m
kubia-3rax1   0/1       Running   0          1m
kubia-3yw4s   0/1       Running   0          1m
```
## Servicio Headless
Un servicio que no tiene asignada una IP en el cluster:  
```
apiVersion: v1
kind: Service
metadata:
  name: kubia-headless
spec:
  clusterIP: None                
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: kubia
```
# Almacenamiento de Disco en contenedores

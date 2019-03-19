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
Los tipos de almacenamiento que podemos asociar a un contenedor son:  

- ___emptyDir___. Se monta un directorio vacio. Cada vez que se para el contenedor, los datos se pierden  
- ___hostPath___. Se monta un directorio del propio nodo, que contendra los datos previamente ya existentes en el directorio  
- ___gitRepo___. Se monta un directorio con el contenido de un repositorio de Git  
- ___nfs___. Una unidad NFS montada en el Pod  
- ___gcePersistentDisk___ (Google Compute Engine Persistent Disk), awsElasticBlockStore (Amazon Web Services Elastic Block Store Volume), azureDisk (Microsoft Azure Disk Volume)  
-	___configMap, secret, downwardAPI___. Almacenientos usados de forma especial  
-	___persistentVolumeClaim___  
- ___cinder, cephfs, iscsi, flocker, glusterfs, quobyte, rbd, flexVolume, vsphere-Volume, photonPersistentDisk, scaleIO___. Used for mounting other types of network storage  

## emptyDir
```
apiVersion: v1
kind: Pod
metadata:
  name: fortune
spec:
  containers:
  - image: luksa/fortune                   
    name: html-generator                   
    volumeMounts:                          
    - name: html                           
      mountPath: /var/htdocs               
  - image: nginx:alpine                    
    name: web-server                       
    volumeMounts:                          
    - name: html                           
      mountPath: /usr/share/nginx/html     
      readOnly: true                       
    ports:
    - containerPort: 80
      protocol: TCP
  volumes:                                 
  - name: html                             
    emptyDir: {}                           
```
Estamos especificando un volumen con el nombre html y de timpo emptyDir en el tag ``volumes`` del spec del Pod. Hay dos imagenes en las que haremos uso de este volumen. Lo indicamos usando el tag ``volumeMounts`` de la imagen. Estamos haciendo referencia al volumen html, e indicamos en que volumen se mapeara. El contenedor tendra esta ruta montaada en el filesystem. En este caso, los dos contenedores del Pod estan compartiendo el volumen - aunque cada uno lo ve en rutas diferentes.  
En el ejemplo anterior el volumen se creo en el disco del nodo sobre el que corra el Pod. Podemos indicar que el disco se cree en memoria:  
```
volumes:
  - name: html
    emptyDir:
      medium: Memory              
```
## gitRepo
Si quisieramos que nuestro volumen contuviera al arrancar el Pod el contenido de un repositorio Git:  
```
apiVersion: v1
kind: Pod
metadata:
  name: gitrepo-volume-pod
spec:
  containers:
  - image: nginx:alpine
    name: web-server
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
      readOnly: true
    ports:
    - containerPort: 80
      protocol: TCP
  volumes:
  - name: html
    gitRepo:                                                           
      repository: https://github.com/luksa/kubia-website-example.git   
      revision: master                                                 
      directory: .                                                     
```
En esencia desde el punto de vista de la spec de las Imagenes no cambia mucho, pero en la spec del volumen indicamos que se trata de un tipo ``getRepo``. Al ser de tipo getRepo tenemos que especificar cual es el repositorio, la branch que queremos utilizar y donde queremos volcar el contenido - en este ejemplo, en el raíz.  Al crear el Pod lo que se hace esencialmente es __clonar__ el repositorio.  

En este ejemplo hemos introducido alguna propiedad más dentro de  spec de la image, para indicar como se comportara el volumen. En este caso hemos indicado que sea ``readOnly``. Hay otras propiedades con las que podemos controlar por ejemplo, si se aceptan lecturas simultaneas desde diferentes clientes, si se puede escribir, si pueden escribir uno o varios, etc.   
### Sidecars
Si una vez el Pod se ha creado, se cambiase algo en el repo, los datos no se sinronizaría. Si quisieramos mantenerlos sincronizados, podriamos crear un sidecar cuya misión sería precisamente la de mantener el repositorio "local" actualizado.  
## hostPath  
Con esta opción estamos apuntando a un directorio concreto del nodo - notese que no podemos anticipar en que nodo el Pod se va a ejecutar, ni si el Pod se movera en un momento dado de un nodo a otro.  
Hay varios system Pods que utilizan este tipo de persistencia para cosas como guardar logs. Por ejemplo:    
```
kubectl get pod s --namespace kube-system

NAME                          READY     STATUS    RESTARTS   AGE
fluentd-kubia-4ebc2f1e-9a3e   1/1       Running   1          4d
fluentd-kubia-4ebc2f1e-e2vz   1/1       Running   1          31d
```
Y ahora:
```
kubectl describe po fluentd-kubia-4ebc2f1e-9a3e --namespace kube-system

Name:           fluentd-cloud-logging-gke-kubia-default-pool-4ebc2f1e-9a3e
Namespace:      kube-system
...
Volumes:
  varlog:
    Type:       HostPath (bare host directory volume)
    Path:       /var/log
  varlibdockercontainers:
    Type:       HostPath (bare host directory volume)
    Path:       /var/lib/docker/containers
```
## Persistence storage
Los tipos de volumenes descritos hasta el momento se caracterizaban por no garantizar el acceso a los datos desde el Pod. Bien eran no persistentes, o cuando lo eran, no podíamos garantizar que si el Pod era rescheduleado tuviera a acceso a los mismos datos. Si precisamos este tipo de persistencia podemos usar el almacenamiento ofrecido por Cloud Providers. Por ejemplo, veamos el caso de Google.  
Podemos ver en Google cloud la lista de almacenamiento persistente usando el siguiente comando:  
```
gcloud container clusters list

NAME   ZONE            MASTER_VERSION  MASTER_IP       ...
kubia  europe-west1-b  1.2.5           104.155.84.137  ...
```
Ahora creamos un almacenamiento persistente llamado mongodb, con 1GB de espacio, y en la zona europa-west1-b:  
```

gcloud compute disks create --size=1GiB --zone=europe-west1-b mongodb

WARNING: You have selected a disk size of under [200GB]. This may result in
     poor I/O performance. For more information, see:
     https://developers.google.com/compute/docs/disks#pdperformance.
Created [https://www.googleapis.com/compute/v1/projects/rapid-pivot-
     136513/zones/europe-west1-b/disks/mongodb].

NAME     ZONE            SIZE_GB  TYPE         STATUS
mongodb  europe-west1-b  1        pd-standard  READY
```
Una vez creado este almacenamiento, podemos utilizarlo en nuestro Pod - siempre que nuestro Kubernetes este ejecutandose en la Google Cloud:  

```
apiVersion: v1
kind: Pod
metadata:
  name: mongodb
spec:
  volumes:
  - name: mongodb-data           
    gcePersistentDisk:           
      pdName: mongodb            
      fsType: ext4               
  containers:
  - image: mongo
    name: mongodb
    volumeMounts:
    - name: mongodb-data         
      mountPath: /data/db        
    ports:
    - containerPort: 27017
      protocol: TCP
```
En la sección ``volumes`` de nuestro ``spec`` indicamos que el tipo de gcePersistentDisk, y especificamos las propiedades asociadas a este persistent disk, esto es, su nombre y que tipo de Filesystem queremos montar en él - en este caso ext4.  

Si ahora borrasemos el Pod, y luego lo volvieramos a crear, los datos volverían a estar disponibles en el Pod tal cual estaban antes de que lo mataramos:    
```
kubectl delete pod mongodb

kubectl create -f mongodb-pod-gcepd.yaml
```
Si nuestro Cluster corriese en otro Cloud Provider, podríamos usar otro tipo de almacenamiento persistente. Por ejemplo, en AWS awsElasticBlockStore, en Azure azureDisk o azureFile.  
```
apiVersion: v1
kind: Pod
metadata:
  name: mongodb
spec:
  volumes:
  - name: mongodb-data
    awsElasticBlockStore:          
      volumeId: my-volume          
      fsType: ext4                 
  containers:
  - ...
```
## Volumen NFS
Para usar un disco compartido:  
```
volumes:
  - name: mongodb-data
    nfs:                      
      server: 1.2.3.4         
      path: /some/path        
```
## Persistent Volume Claims (PVC)
En todos los casos anteriores el propio desarrollador tenía que "buscarse la vida" para encontrar el espacio de disco que necesitaba para luego montarlo en su Pod. Con los PVC vamos a desacoplar la actividad del desarrollar - crear el Pod - con la actividad del system administrator - provisionar el espacio de disco.  

El administrador creara ``Persistent Volumes`` o PC, y el desarrollador creará ``Persistent Volume Claims`` o PVC. En el Pod nos referiremos a la PVC.  

### Persistent Volume
El PV es un recurso Kubernetes más, y como tal se creara. En la spec del PV indicamos el espacio que tendra asociado, como se accedera a él, cual es la política de retención - que queremos que suceda cuando el Pod deje de usar el PV -, y el tipo de disco - en este ejemplo hemos especificado que sea un almacenamiento persistente de Google Cloud:  
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-pv
spec:
  capacity:                                 
    storage: 1Gi                            
  accessModes:                              
  - ReadWriteOnce                           
  - ReadOnlyMany                            
  persistentVolumeReclaimPolicy: Retain     
  gcePersistentDisk:                        
    pdName: mongodb                         
    fsType: ext4                            
```
Una vez el recurso se haya creado:  
```
kubectl get pv

NAME         CAPACITY   RECLAIMPOLICY   ACCESSMODES   STATUS      CLAIM
mongodb-pv   1Gi        Retain          RWO,ROX       Available
```
Podemos observar que el el PV esta disponible y que no tiene ninguna "claim" en este momento.

__NOTA:__ Los PV _no están asociados a ningun namespace_, esto es, estaran disponibles para cualquier Pod, independientemente de a que namespace pertenezcan.  
### Persistent Volume Claim
El PVC es otro tipo de recurso:  
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc              
spec:
  resources:
    requests:                    
      storage: 1Gi               
  accessModes:                   
  - ReadWriteOnce                
  storageClassName : ""          
```
Tan pronto se ha creado un PVC, Kubernetes buscara una PV que sea "compatible" y lo vinculara.  
```
kubectl get pvc

NAME          STATUS    VOLUME       CAPACITY   ACCESSMODES   AGE
mongodb-pvc   Bound     mongodb-pv   1Gi        RWO,ROX       3s
```
Aqui podemos ver como nuestra PVC ya se ha vinculado - status ``Bound``-, y que se ha vinculado a "mongodb-pv". Los access modes son:  

- _RWO—ReadWriteOnce_. Solo se puede leer/escribir desde un nondo; Solo un nodo podrá montar el volumen.  
- _ROX—ReadOnlyMany_. Varios nodos pueden montar el volumen, pero solo para leer.
- _RWX—ReadWriteMany_. Varios nodos pueden montar el volumen, y cada nodo puede leer y escribir.

Si listamos ahora el PV:  
```
kubectl get pv

NAME         CAPACITY   ACCESSMODES   STATUS   CLAIM                 AGE
mongodb-pv   1Gi        RWO,ROX       Bound    default/mongodb-pvc   1m
```
Observamos que efectivamente ahora tiene asociada una Claim. Con la claim se indica también el namespace - esto porque el PV esta disponible en todos los namespaces.  

Una vez hemos creado nuestro PVC, para utilizarla en un Pod:  
```
apiVersion: v1
kind: Pod
metadata:
  name: mongodb
spec:
  containers:
  - image: mongo
    name: mongodb
    volumeMounts:
    - name: mongodb-data
      mountPath: /data/db
    ports:
    - containerPort: 27017
      protocol: TCP
  volumes:
  - name: mongodb-data
    persistentVolumeClaim:          
      claimName: mongodb-pvc        
```
Podemos observar como el procedimiento es el mismo que con otros tipos de almacenamiento. En la sección ``volume`` de nuestro ``spec`` indicamos que queremos usar un ``persistentVolumeClaim`` y su nombre.  
### Reciclar un PVC
Si borrasemos nuestro Pod, y el PVC, que sucederia?:  
```
kubectl delete pod mongodb

kubectl delete pvc mongodb-pvc
```
Si ahora recreasemos el PVC, y comprobasemos su estado:  
```
kubectl get pvc

NAME           STATUS    VOLUME       CAPACITY   ACCESSMODES   AGE
mongodb-pvc    Pending                                         13s
```
El PVC no esta disponible, ni se ha asociado automáticamente a un PV como hizo la primera vez. Si consultasemos el estado del PV:  
```
kubectl get pv

NAME        CAPACITY  ACCESSMODES  STATUS    CLAIM               REASON AGE
mongodb-pv  1Gi       RWO,ROX      Released  default/mongodb-pvc        5m
```
Vemos que el PV esta ahí, que sigue figurando la claim que tuvo al inicio, pero que el estado es ``Released``. Lo que sucede es qeu como indicamos una política de Retain en el PVC, cuando el PVC es eliminado los datos no se pierden. Al mismo tiempo, si al crear un PVC se volviese a bindear automáticamente, podría suceder que alguien que no deba vea los datos. Por ese motivo, cuando la política es ``Retain`` si bien los datos no se pierdem el PV no se vuelbe a bindear automaticamente con otro PVC.  

Hay otras dos políticas disponibles:  
- _Recycle_. Borra el contenido del PV, y lo pone de nuevo a disposición de cualquier PVC.
- _Delete_. Borra el PV, incluyendo su contenido.  

### Storage Class. Provisionamiento Dinámico
En el mecanismo que acabamos de describir ya hay una separación de roles, por un lado el Adminsitrador encargado de crear los PV, y por otro lado el desarrollador encargado de crear los PVC. En este esquema el administrador sigue necesitando crear el persistent volume por anticipado, asi que se precisa una coordinación entre los dos roles, una coordinación para cada caso, para cada Pod que se necesite crear.  
Hay un recurso, el Storage Class que simplifica la necesidad de coordinación. Se crea como cualquier otro recurso:  
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/gce-pd        
parameters:
  type: pd-ssd                           
  zone: europe-west1-b                   
```
En el storage class tenemos que especificar el provisionador del almacenamiento. En este caso estamos usando el ``Google Compute Engine (GCE) Persistent Disk (PD) provisioner``. Esto obviamente significa que esta Storage Class solo puede ser creada cuando estemos usando Kubernetes en la Google Cloud. Ahora al crear el PVC podemos especificar la Storage Class - junto con nuestras necesidades de almacenamiento. El  
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
spec:
  storageClassName: fast             
  resources:
    requests:
      storage: 100Mi
  accessModes:
    - ReadWriteOnce
```
Podemos ver como el pvc tiene ahora asociada la clase de almacenamiento:  
```
kubectl get pvc mongodb-pvc

NAME          STATUS   VOLUME         CAPACITY   ACCESSMODES   STORAGECLASS
mongodb-pvc   Bound    pvc-1e6bc048   1Gi        RWO           fast
```
Podemos observar como seguimos teniendo un PV detrás del PVC, solo que se ha creado automáticamente con la clase especificada:  
```
kubectl get pv

NAME           CAPACITY  ACCESSMODES  RECLAIMPOLICY  STATUS    STORAGECLASS
mongodb-pv     1Gi       RWO,ROX      Retain         Released
pvc-1e6bc048   1Gi       RWO          Delete         Bound     fast
```
Como en este caso la clase esta configurada para utilizar el provisionador de Google, podemos ver que efectivamente se ha creado ``dinámicamente`` almacenamiento persistente en la cloud:  
```
gcloud compute disks list

NAME                          ZONE            SIZE_GB  TYPE         STATUS
gke-kubia-dyn-pvc-1e6bc048    europe-west1-d  1        pd-ssd       READY
gke-kubia-default-pool-71df   europe-west1-d  100      pd-standard  READY
 gke-kubia-default-pool-79cd   europe-west1-d  100      pd-standard  READY
gke-kubia-default-pool-blc4   europe-west1-d  100      pd-standard  R EADY
__mongodb__                       europe-west1-d  1        pd-standard  READY
```

__Nota__: Como las PVC se refieren al storageClass por nombre, si llevasemos nuestro PVC a otro cluster en el que existiese esta storageClass, el PVC seria valido. Esto es, con las storageClass conseguimos portabilidad entre clusters.  

Podemos recuperar la lista de storageClaseses disponibles:  
 ```
kubectl get sc

NAME                 TYPE
fast                 kubernetes.io/gce-pd
standard (default)   kubernetes.io/gce-pd
```

## Config Maps
Podemos configurar contenedores de dos formas:  
- Usando argumentos pasados por línea de comandos.
- Usando variables de entorno.

### Argumentos
Supongamos que tenemos el siguiente script:  
```
#!/bin/bash
trap "exit" SIGINT
INTERVAL=$1
echo Configured to generate new fortune every $INTERVAL seconds
mkdir -p /var/htdocs
while :
do
  echo $(date) Writing fortune to /var/htdocs/index.html
  /usr/games/fortune > /var/htdocs/index.html
  sleep $INTERVAL
done
```

Tomamos el valor de ``INTERVAL`` del primer argumento de la línea de comandos. Ahora hagamos una imagen Docker con este script:  
```
FROM ubuntu:latest
RUN apt-get update ; apt-get -y install fortune
ADD fortuneloop.sh /bin/fortuneloop.sh
ENTRYPOINT ["/bin/fortuneloop.sh"]                 
CMD ["10"]                                         
```
En este Dockerfile estamos creando una imagen basada en la última imagen de ubuntu, sobre la imagen hacemos un ``apt-get update`` y luego un ``apt-get -y install fortune`` para instalar la aplicación fortune. A continuación tomamos de nuestra máquina el script  ``fortuneloop.sh`` y lo copiamos en la imagen en la ruta ``/bin/fortuneloop.sh``. El script es el que hemos listado antes. A continuación definimos que aplicación sea la que se ejecute cuando el contenedor se cree a partir de esta imagen. Hemos indicado que sea ``/bin/fortuneloop.sh``. Finalmente especificamos cual sera el argumento por defecto, en caso de que no se pasara ninguno al arrancar el contenedor. En este caso será ``10``.  

Lo que sucede aquí es que tenemos una imagen que ejecutar el script antes listado, y que tendrá como primer argumento, ``$1``, el valor 10 o el que especifiquemos por línea de comandos.  

Construimos la imagen y la publicamos (kubctl tiene que descargar las imagenes de un repositorio):
```
docker build -t docker.io/luksa/fortune:args .

docker push docker.io/luksa/fortune:args

docker run -it docker.io/luksa/fortune:args
```
Podemos especificar los argumentos de la imagen al definir el Pod:  
```
kind: Pod
spec:
  containers:
  - image: some/image
    command: ["/bin/command"]
    args: ["arg1", "arg2", "arg3"]
```
Por ejemplo, en nuestro caso:  
```
apiVersion: v1
kind: Pod
metadata:
  name: fortune2s                    
spec:
  containers:
  - image: luksa/fortune:args        
    args: ["2"]                      
    name: html-generator
    volumeMounts:
    - name: html
      mountPath: /var/htdocs
...
```
Hemos indicado nuestra imagen, y hemos pasado como argumento el valor 2; El contenedor se ejecutar con este valor y no con el defecto que especificamos con CMD en el Dockerfile.  

### Variables de entorno
Otra forma de configurar nuestro contenedor es con variables de entorno.  
```
#!/bin/bash
trap "exit" SIGINT
echo Configured to generate new fortune every $INTERVAL seconds
mkdir -p /var/htdocs
while :
do
  echo $(date) Writing fortune to /var/htdocs/index.html
  /usr/games/fortune > /var/htdocs/index.html
  sleep $INTERVAL
done
```
Notese que en esta ocasión no hemos seteado el valor de la variable de entorno INTERVAL.  

En la especificación del Pod podremos definir variables de entorno:  
```
kind: Pod
spec:
 containers:
 - image: luksa/fortune:env
   env:                            
   - name: INTERVAL                
     value: "30"                   
   name: html-generator
```
### ConfigMaps
Con configMaps podemos configurar listas de key/values que se pueden mapear al Pod bien como un volumen de disco más, o bien dando valores a variables de entorno o a argumentos. El configMap se puede construir con literales key/value, o bien especificando un archivo, en cuyo caso el nombre del archivo pasa a ser el Key, y el contenido del archivo - por ejemplo, un json - pasa a ser el valor.  

Aqui creamos un configMap con una lista de valores:  
```
kubectl create configmap fortune-config --from-literal=sleep-interval=25
```
Crea un config map llamado ``fortune-config`` que tiene un key ``sleep-interval`` que toma el valor ``25``.  
```
kubectl create configmap myconfigmap
   --from-literal=foo=bar --from-literal=bar=baz --from-literal=one=two
```
El config map es un recurso más:  
```
kubectl get configmap fortune-config -o yaml

apiVersion: v1
data:
  sleep-interval: "25"                                  
kind: ConfigMap                                         
metadata:
  creationTimestamp: 2016-08-11T20:31:08Z
  name: fortune-config                                  
  namespace: default
  resourceVersion: "910025"
  selfLink: /api/v1/namespaces/default/configmaps/fortune-config
  uid: 88c4167e-6002-11e6-a50d-42010af00237
```
Podemos usar un yaml para crear el recurso:  
```
kubectl create -f fortune-config.yaml
```
Como indicabamos anteriormente, podemos hacer que el config map tenga el contenido de un archivo de configuración:  
```
kubectl create configmap my-config --from-file=config-file.conf
```
Esto creara un config map con una key ``config-file.conf`` que tendra como valor el contenido del archivo. Si tuvieramos varios archivos, en lugar de ejecutar insrtrucción uno por uno, podemos crear el config map con todos los archivos de un directorio:  
```
kubectl create configmap my-config --from-file=/path/to/dir
```
Por supuesto siempre podemos hacerlo archivo a archivo:  
```
kubectl create configmap my-config
   --from-file=foo.json                     
   --from-file=bar=foobar.conf              
   --from-file=config-opts/                 
   --from-literal=some=thing                
```
### Usar un ConfigMap en un contenedor
#### ConfigMap con una variable de entorno
Podemos asignar el valor de un configMap a una variable de entorno:  
```
apiVersion: v1
kind: Pod
metadata:
  name: fortune-env-from-configmap
spec:
  containers:
  - image: luksa/fortune:env
    env:                             
    - name: INTERVAL                 
      valueFrom:                     
        configMapKeyRef:             
          name: fortune-config       
          key: sleep-interval
          optional: true        
...
```
Hemos establecido que se usara el configMap ``fortune-config`` y que usaremos la key ``sleep-interval``. Con ``optional`` podemos indicar si el valor es opcional. Podemos asignar valores a mas de una variable de entorno a la vez:  
```
spec:
  containers:
  - image: some-image
    envFrom:                      
    - prefix: CONFIG_             
      configMapRef:               
        name: my-config-map       
...
```  
Usamos ``envFrom`` en lugar de ``env``. Todas los keys del configMap se crearan como variables de entorno. La variable de entorno tendra el mismo nombre de la key, bueno, en este caso con el prefijo CONFIG_. Solo __hacer una salvedad__, si el nombre de una key no es un nombre válido para una variable de entorno, Kubernetes la ignorara.  
#### ConfigMap con un volumen
Podemos crear un volumen que se mapee a un configMap. Cuando el contenedor quiera acceder al volumen lo que vera es el contenido del confMap, esto es, sus claves figuraran como archivos, y el contenido sera el de sus valores:  

```
apiVersion: v1
kind: Pod
metadata:
  name: fortune-configmap-volume
spec:
  containers:
  - image: nginx:alpine
    name: web-server
    volumeMounts:
    ...
    - name: config
      mountPath: /etc/nginx/conf.d      
      readOnly: true
    ...
  volumes:
  ...
  - name: config
    configMap:                          
      name: fortune-config              
  ...
```
Si nos interesase exponer todas las entradas del configMap podemos añadir la propiedad items. Con items estamos diciendo que entradas serán expuestas:    
```
volumes:
  - name: config
    configMap:
      name: fortune-config
      items:                             
      - key: my-nginx-config.conf        
        path: gzip.conf                  
```
__Nota:__ Podemos refrescar el contenido de un configMap e inmediatamente el configMap con los nuevos valores estara disponible en el contenedor. Eso si, será responsabilidad del contenedor refrescar - releer - el configMap.  
## Secrets
Cuando los valores de configuración que necesitamos guardar corresponden con información confidencial, Kubernetes nos ofrece la posibilidad de usar Secrets. Con Secrets los valores solo se distribuyen a los nodos que lo necesitan, y solamente estan cargados en memoria, nunca se guardan en disco. Los valores se guardan en el Mater node, en el ectd encriptados - desde la versión 1.7 de kubernetes.  
```
kubectl get secrets


NAME                  TYPE                                  DATA      AGE
default-token-cfee9   kubernetes.io/service-account-token   3         39d
```
Podemos ver los detalles:  
```
kubectl describe secrets


Name:        default-token-cfee9
Namespace:   default
Labels:      <none>
Annotations: kubernetes.io/service-account.name=default
             kubernetes.io/service-account.uid=cc04bb39-b53f-42010af00237
Type:        kubernetes.io/service-account-token

Data
====
ca.crt:      1139 bytes                                   
namespace:   7 bytes                                      
token:       eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...      
```
Podemos crear un secret como cualquier otro recurso:  
```
kubectl create secret generic fortune-https --from-file=https.key
   --from-file=https.cert --from-file=foo
```
En este ejemplo hemos creado un secret con tres entradas, y ambas entradas se toman de tres archivos. Si vieramos la configuración de este recurso:  
```
kubectl get secret fortune-https -o yaml


apiVersion: v1
data:
  foo: YmFyCg==
  https.cert: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCekNDQ...
  https.key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcE...
kind: Secret
```
Observese como tenemos los tres valores - como habríamos visto de haberlo creadon en un configMap - pero los valores están códificados en ``base64``. Usar base64 no es precisamente guardar valores encriptados, pero nos permite que el valor guardado sea un valor ``binario``. Si quisieramos guardar un valor sin codificar en base64 en un secret, tambien se puede hacer:  
```
kind: Secret
apiVersion: v1
stringData:                                    1
  foo: plain text                              2
data:
  https.cert: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCekNDQ...
  https.key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcE...
```
Basta con usar la propiedad ``stringData`` en lugar de ``data``.  
## Metadatos. Downward api
La downward api nos proporciona información sobre el entorno en el que Kubernetes esta ejecutandose. __No es un REST endpoint__, es más bien un volumen en el que tendremos acceso a metadata del entorno. La información que nos brinda es la siguiente:  
-	The pod’s name
-	The pod’s IP address
-	The namespace the pod belongs to
-	The name of the node the pod is running on
-	The name of the service account the pod is running under
-	The CPU and memory requests for each container
-	The CPU and memory limits for each container
-	The pod’s labels
-	The pod’s annotations


### Exponer los medatos en variables de entorno
Vemos como exponer todas estas propiedades atraves de variables de entorno:  
```
apiVersion: v1
kind: Pod
metadata:
  name: downward
spec:
  containers:
  - name: main
    image: busybox
    command: ["sleep", "9999999"]
    resources:
      requests:
        cpu: 15m
        memory: 100Ki
      limits:
        cpu: 100m
        memory: 4Mi
    env:
    - name: POD_NAME
      valueFrom:                                   
        fieldRef:                                  
          fieldPath: metadata.name                 
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: SERVICE_ACCOUNT
      valueFrom:
        fieldRef:
          fieldPath: spec.serviceAccountName
    - name: CONTAINER_CPU_REQUEST_MILLICORES
      valueFrom:                                   
        resourceFieldRef:                          
          resource: requests.cpu                   
          divisor: 1m                              
    - name: CONTAINER_MEMORY_LIMIT_KIBIBYTES
      valueFrom:
        resourceFieldRef:
          resource: limits.memory
          divisor: 1Ki
```
En el caso de los recursos, CPU y Memoria, especificamos tambien un divisor. Lo que medimos en CPU son los miliseconds por core. En memoria memory limits/request (ver más adelante el significado). Los valores adminisbles para el divisor de memoria son: 1 (byte), 1k (kilobyte) or 1Ki (kibibyte), 1M (megabyte) or 1Mi (mebibyte), ...  

Si consultamos ahora las variables de entorno de nuestro pod:  
```
kubectl exec downward env

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=downward
CONTAINER_MEMORY_LIMIT_KIBIBYTES=4096
POD_NAME=downward
POD_NAMESPACE=default
POD_IP=10.0.0.10
NODE_NAME=gke-kubia-default-pool-32a2cac8-sgl7
SERVICE_ACCOUNT=default
CONTAINER_CPU_REQUEST_MILLICORES=15
KUBERNETES_SERVICE_HOST=10.3.240.1
KUBERNETES_SERVICE_PORT=443
...
```
### Exponer los medatos en un volumen
Podemos definir un pod con un volumen que exponga como items los metadatos ofrecidos por la downward api. Las imagenes definidas en la spec del pod podran entonces montar como volumenes el contenido de la downward api:     
```
apiVersion: v1
kind: Pod
metadata:
  name: downward
  labels:                                     
    foo: bar                                  
  annotations:                                
    key1: value1                              
    key2: |                                   
      multi                                   
      line                                    
      value                                   
spec:
  containers:
  - name: main
    image: busybox
    command: ["sleep", "9999999"]
    resources:
      requests:
        cpu: 15m
        memory: 100Ki
      limits:
        cpu: 100m
        memory: 4Mi
    volumeMounts:                             
    - name: downward                          
      mountPath: /etc/downward                
  volumes:
  - name: downward                            
    downwardAPI:                              
      items:
      - path: "podName"                       
        fieldRef:                             
          fieldPath: metadata.name            
      - path: "podNamespace"
        fieldRef:
          fieldPath: metadata.namespace
      - path: "labels"                            
        fieldRef:                                 
          fieldPath: metadata.labels              
      - path: "annotations"                       
        fieldRef:                                 
          fieldPath: metadata.annotations         
      - path: "containerCpuRequestMilliCores"
        resourceFieldRef:
          containerName: main
          resource: requests.cpu
          divisor: 1m
      - path: "containerMemoryLimitBytes"
        resourceFieldRef:
          containerName: main
          resource: limits.memory
          divisor: 1
```
Asi por ejemplo, ``/etc/downward/podName`` sera un archivo disponible en la imagen que contendra el nombre del pod. Si listamos el volumen del pod veriamos:  
```
kubectl exec downward ls -lL /etc/downward

-rw-r--r--   1 root   root   134 May 25 10:23 annotations
-rw-r--r--   1 root   root     2 May 25 10:23 containerCpuRequestMilliCores
-rw-r--r--   1 root   root     7 May 25 10:23 containerMemoryLimitBytes
-rw-r--r--   1 root   root     9 May 25 10:23 labels
-rw-r--r--   1 root   root     8 May 25 10:23 podName
-rw-r--r--   1 root   root     7 May 25 10:23 podNamespace
```
### Kubernetes API server
Otra forma de obtener información de contexto es invocando a [la api de Kubernetes](KubernetesAPI.md).  

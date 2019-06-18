# Introducción
Los Persistent Volumes (PV) que hemos visto se definen en un Pod template. Todas las instancias de un Pod usaran el mismo PV. Si quisieramos que cada Pod tuviera acceso exclusivo a almacenamiento, habrá que buscar una alternativa:
- Crear dentro del PV varios directorios, de modo que cada directorio sea exclusivo para cada Pod. Esto require de una coordinación, que cada instancia sepa "quien es", y que trabaje de forma diferente a las anteriores  
- Crear Pods individualmente, sin gobernarlos con un RS  
- Crear un tantos RS como Pods haya que crear. Asi tenemos el elemento de feedback, pero cada Pod puede tener su almacenamiento exclusivo  

Lo que caracteriza a un Stateful Pod es:  
- __Identidad__. Tener una identidad fija (fqnm y dirección IP). No importa donde o cuando el Pod es scheduleado, siempre podemos dirigirnos a el de la misma forma  
- Tener un __almacenamiento dedicado__. Los datos del Pod estaran siempre accesible al Pod independientemente de cuando y donde sea scheduleado


## Identidad
Necesitaremos poder localizar el Pod en una dirección que no cambie cuando el Pod se schedulea en otro nod. El servicio nos ofrece esta capacidad, pero el servicio sirve a más de un Pod. Si crearamos un servicio por cada Pod funcionaria, pero seria dificil de manejar. Tendriamos un RS y un servicio por Pod, con lo cual tendriamos que tener una etiqueta especifica con cada Pod:  

![manualstatefull.png](Imagenes\manualstatefull.png)

## Almacenamiento
Aquí lo tenemos también dificil. Si en el Pod tenemos almacenamiento persistente y queremos que este disponible independientemente del nodo, usaremos un PV y un PVC. El problema esta en que el PVC se asocia al Pod template, con lo cual todas las instancias del Pod compartirían el mismo almacenamiento. Si quisieramos asignar un PV a un Pod concreto, tendríamso que tener distintos Pod templates - y cada uno en su propio RS.

Obviamente se encesita una forma mejor de gestionar esto: El ``recurso StatefulSet``.

# StatefulSet
El Statefulset es un __recurso__ que nos proporciona esta funcionalidad que buscamos de forma transparente.  

Cuando un Pod stateful muere, necesitamos que se reconstruya con la misma identidad, y con los mismos datos - estado -, y con el mismo nombre, aunque el scheduler lo resurrecte en otro nodo. Esto se consigue gracias a que el todos los Pods creados con este __tienen un nombre previsible__. En esta imagen podemos ver en la izquierda un RS y un set de Pods tradicionales, y en la derecha podemos ver el equivalente creados con un Statefulset:  

![PodsEnStatefulSets.png](Imagenes\PodsEnStatefulSets.png)  

Podemos ver como el nombre de los Pods en la derecha tiene un nombre __previsible__. Tanto es así que si un nodo muere y se crea otro para sustituirle, el Pod que se creara tendra exactamente el mismo nombre - , y tendrá los mismos datos asociados como veremos a continuación.  

Cundo se reduce el numero de instancias en el RS creado con este recurso, tambie es previsbible como se va a hacer. Se empezará eliminando los Pods que se crearon en último lugar. Además, cuando se reduce el numero de instancias en más de una, los Pods se iran eliminado uno a uno, de forma secuencial. Esto se hace asi porque hay aplicaciones stateful que no aceptan facilmente la caida de varios modulos. Por ejemplo, supongamos que nuestros Pods implementan un cluster de Kafka. Cuando un nodo se elimine, los logs replicados en el nodo caido tendran que se ser replicados en otros. Si muriesen más de un nodo a la vez podría suceder que alguna de las replicas se perdieran.  

![EscaladoStateful.png](Imagenes\EscaladoStateful.png)  


Además de hacer el escalado secuencial, Kubernetes tampoco permitirá el scale down si alguno de los Pods no es saludable - definido por la readiness probe -. Si lo hiciera, estaríamos parando más de un Pod a la vez - el que no es saludable y otro.  


## Almacenamiento
Como indicamos antes, lo que tendríamos que hacer es generar tantos PVC como Pods tengamos, de forma que cada Pod use su PVC. ¿Como lograr esto?, el StatefulSet utilizara un PVC template, de modo que asigna a cada nodo un PVC, y no solo eso, lo hace en una forma previsible, de modo que si el Pod es scheduleado a otro nodo, seguira teniendo su PVC, y por lo tanto "sus datos".  


![TemplatedPVC.png](Imagenes\TemplatedPVC.png)  

Los PV asociados no pueden aliminarse cuando un Pod se elimina. Si queremos borrar los datos tendremos que hacerlo manualmente:  


![TemplatedPVCDeletio.png](Imagenes\TemplatedPVCDeletio.png)  

## Garantias Stateful
Ademas de los aspectos de identidad - fqdn, e Ip -, y almacenamiento, los StatefulSets tiene otra peculiaridad. Si un Pod no esta saludable, y Kubernetes arranca otro, tendremos dos nodos con el mismo nombre a la vez, __accediendo el mismo almacenamiento__. Esto significa que Kubernetes tiene que añadir garantias de __"como máximo uno"__ en este tipo de recursos.  

# Ejemplo
## Aplicación
Creamos una aplicación en Node.js. Tiene does endpoints. Uno guarda los datos en un archivo _local_, y el otro consulta los datos, leyendolos del archivo:  
```
(...)

const dataFile = "/var/data/kubia.txt";

(...)

var handler = function(request, response) {
  if (request.method == 'POST') {
    var file = fs.createWriteStream(dataFile);                     
    file.on('open', function (fd) {                                
      request.pipe(file);                                          
      console.log("New data has been received and stored.");       
      response.writeHead(200);                                     
      response.end("Data stored on pod " + os.hostname() + "\n");  
    });
  } else {
    var data = fileExists(dataFile)                                
      ? fs.readFileSync(dataFile, 'utf8')                          
      : "No data posted yet";                                      
    response.writeHead(200);                                       
    response.write("You've hit " + os.hostname() + "\n");          
    response.end("Data stored on this pod: " + data + "\n");       
  }
};

var www = http.createServer(handler);
www.listen(8080);
```
El dockerfile:  
```
FROM node:7
ADD app.js /app.js
ENTRYPOINT ["node", "app.js"]
```
## Creamos los PV
Creamos tres PV en google. Lo único especial que estamos haciendo es que cremos los PV en una sola operación, usando el recurso ``List``:  
```
kind: List                                     
apiVersion: v1
items:
- apiVersion: v1
  kind: PersistentVolume                       
  metadata:
    name: pv-a                                 
  spec:
    capacity:
      storage: 1Mi                             
    accessModes:
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Recycle     
    gcePersistentDisk:                         
      pdName: pv-a                             
      fsType: nfs4                             
- apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: pv-b

 (...)
```
## Servicio
Creamos un servicio __headeless__. Para que sea headeless, es decir, si ser accesible, especificamos ``ClusterIP: None``:  
```
apiVersion: v1
kind: Service
metadata:
  name: kubia             
spec:
  clusterIP: None         
  selector:               
    app: kubia            
  ports:
  - name: http
    port: 80
```
## StatefulSet
Creamos el recurso Stateful. Notese como __hacemos referencia al servicio antes creado__:  
```
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: kubia
spec:
  serviceName: kubia
  replicas: 2
  template:
    metadata:
      labels:                        
        app: kubia                   
    spec:
      containers:
      - name: kubia
        image: luksa/kubia-pet
        ports:
        - name: http
          containerPort: 8080
        volumeMounts:
        - name: data                 
          mountPath: /var/data       
  volumeClaimTemplates:
  - metadata:                        
      name: data                     
    spec:                            
      resources:                     
        requests:                    
          storage: 1Mi               
      accessModes:                   
      - ReadWriteOnce                
```
Destacar la entrada ``volumeClaimTemplates``. Aquie estamos definiendo no un PVC, pero un template de PVC. Otra cosa a observar es que estamos solicitando dos instancias de Pod. Creamos el recurso:  
```
kubectl create -f kubia-statefulset.yaml
```
Podemos ver los Pods:  
```
kubectl get po

NAME      READY     STATUS              RESTARTS   AGE
kubia-0   0/1       ContainerCreating   0          1s
```
Podemos ver un solo Pod, y con el estado ``ContainerCreating``. Como indicamos antes, los Pods se crean de forma secuencial, _por eso solo vemos uno_. Un ratito más tarde:  
```
kubectl get po

NAME      READY     STATUS              RESTARTS   AGE
kubia-0   1/1       Running             0          8s
kubia-1   0/1       ContainerCreating   0          2s
```
Si miramos la descripción de los Pods creados, vamos a ver que tienen un PVC _concreto_ asociado:  
```
kubectl get po kubia-0 -o yaml
apiVersion: v1
kind: Pod
metadata:
  ...
spec:
  containers:
  - image: luksa/kubia-pet
    ...
    volumeMounts:
    - mountPath: /var/data                 1
      name: data                           1
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-r2m41
      readOnly: true
  ...
  volumes:
  - name: data                             
    persistentVolumeClaim:                 
      claimName: data-kubia-0              
  - name: default-token-r2m41
    secret:
      secretName: default-token-r2m41
```
Aqui podemos ver que efectivamente hay un PVC llamado ``data-kubia-0``. Si listamos los PVC:  
```
kubectl get pvc

NAME           STATUS    VOLUME    CAPACITY   ACCESSMODES   AGE
data-kubia-0   Bound     pv-c      0                        37s
data-kubia-1   Bound     pv-a      0                        37s
```
Vemos como efectivamente nuestro PVC está "ahi", y que esta ``bound`` a un volumen llamado ``pv-c``.
## Comunicación con los Pods
Como el Pod es headeless, no tiene IP asociada, no hay forma de acceder a los Pods a traves del servicio. Podemos usar el Kubernetes proxy:  
```
<apiServerHost>:<port>/api/v1/namespaces/default/pods/kubia-0/proxy/<path>
```
Para eso hay que activar el plugin:  
```
kubectl proxy
```
Ya podemos hacer una llamada al Pod:  
```
curl localhost:8001/api/v1/namespaces/default/pods/kubia-0/proxy/

You've hit kubia-0
Data stored on this pod: No data posted yet
```
Aqui estamos llamando al pod ``kubia-0``. Cuando hacemos la llamada, la petición hace varios saltos:  
- Kubernetes proxy que corre en el nodo    
- El proxy llama al API Server    
- El API Server llama al Pod especificado  


![StatefulProxies.png](Imagenes\StatefulProxies.png)
## Borrado de Pods
Si borramos un Pod:  
```
kubectl delete po kubia-0
```
Si ahora consultamos los Pods:  
```
kubectl get po

NAME      READY     STATUS        RESTARTS   AGE
kubia-0   1/1       Terminating   0          3m
kubia-1   1/1       Running       0          3m
```
Tan pronto se borre el Pod:  
```
kubectl get po

NAME      READY     STATUS              RESTARTS   AGE
kubia-0   0/1       ContainerCreating   0          6s
kubia-1   1/1       Running             0          4m
```
Y un poco más tarde:  
```
kubectl get po

NAME      READY     STATUS    RESTARTS   AGE
kubia-0   1/1       Running   0          9s
kubia-1   1/1       Running   0          4m
```
Lo que sucedera es que el PV no se elimina cuando el Pod se elimina, y que cuando un nuevo Pod es creado, se crea con la misma identidad del "eliminado", y mapeara el mismo PV, independientemente de cual sea el nodo en el que el Pod haya sido scheduleado:  


![StatefulBorrado.png](Imagenes\StatefulBorrado.png)   

Si volvieramos a llamar al Pod "recreado", veremos que los datos siguen ahí:  
```
curl localhost:8001/api/v1/namespaces/default/pods/kubia-0/proxy/

You've hit kubia-0
Data stored on this pod: Hey there! This greeting was submitted to kubia-0.
```
## Servicio "normal"
Podemos exponer los Pods con un servicio normal, accesible desde el cluster o fuera del cluster. El procedimiento para crear este servicio es estándard:  
```
apiVersion: v1
kind: Service
metadata:
  name: kubia-public
spec:
  selector:
    app: kubia
  ports:
  - port: 80
    targetPort: 8080
```
## Usar DNS para localizar "Peers"
Podemos localizar un Stateful Peer utilizando el servicio de DNS. Añadimos el módulo DNS a nuestra aplicación node.js:  
```
(...)

const dns = require('dns');

const dataFile = "/var/data/kubia.txt";
const serviceName = "kubia.default.svc.cluster.local";
const port = 8080;

(...)

var handler = function(request, response) {
  if (request.method == 'POST') {
    ...
  } else {
    response.writeHead(200);
    if (request.url == '/data') {
      var data = fileExists(dataFile)
        ? fs.readFileSync(dataFile, 'utf8')
        : "No data posted yet";
      response.end(data);
    } else {
      response.write("You've hit " + os.hostname() + "\n");
      response.write("Data stored in the cluster:\n");

      //Localizamos un peer
      dns.resolveSrv(serviceName, function (err, addresses) {         
        if (err) {
          response.end("Could not look up DNS SRV records: " + err);
          return;
        }
        var numResponses = 0;
        if (addresses.length == 0) {
          response.end("No peers discovered.");
        } else {
          //Para cada una de las direcciones encontradas enviamos una request
          addresses.forEach(function (item) {                         
            var requestOptions = {
              host: item.name,
              port: port,
              path: '/data'
            };
            httpGet(requestOptions, function (returnedData) {         
              numResponses++;
              response.write("- " + item.name + ": " + returnedData);
              response.write("\n");
              if (numResponses == addresses.length) {
                response.end();
              }
            });
          });
        }
      });
    }
  }
};

(...)

```
## Node Failures
Antes de crear un Pod para reemplazar a otro, Kubernetes tiene que estar al 100% seguro de que el Pod que el Pod que va a reemplazar esta "muerto", porque de lo contrario terminaríamos con dos Pods con el mismo nombre y accediendo al mismo almacenamiento. Vamos a ver esto con un ejemplo. Para simular que el Pod está "muerto", vamos a deshabilitar su adaptador de red.  

Nos conectamos al nodo via ssh:  
```
gcloud compute ssh gke-kubia-default-pool-32a2cac8-m0g1
```
Una vez dentro, desactivamos el adaptador de red:  
```
sudo ifconfig eth0 down
```
Si vemos los datos del nodo:  
```
kubectl get node

NAME                                   STATUS     AGE       VERSION
gke-kubia-default-pool-32a2cac8-596v   Ready      16m       v1.6.2
gke-kubia-default-pool-32a2cac8-m0g1   NotReady   16m       v1.6.2
gke-kubia-default-pool-32a2cac8-sgl7   Ready      16m       v1.6.2
```
Vemos como efectivamente el master no es capaz de ver el nodo que acabamos de manipular. Si ahora listamos los Pods:  
```
kubectl get po

NAME      READY     STATUS    RESTARTS   AGE
kubia-0   1/1       Unknown   0          15m
kubia-1   1/1       Running   0          14m
kubia-2   1/1       Running   0          13m
```
y  
```
kubectl describe po kubia-0

Name:        kubia-0
Namespace:   default
Node:        gke-kubia-default-pool-32a2cac8-m0g1/10.132.0.2
...
Status:      Terminating (expires Tue, 23 May 2017 15:06:09 +0200)
Reason:      NodeLost
Message:     Node gke-kubia-default-pool-32a2cac8-m0g1 which was
             running pod kubia-0 is unresponsive
```
Kubernetes no recreara el Pod. Tendremos que borrarlo nosotros manualmente:  
```
kubectl delete po kubia-0  
```
Veamos:  
```
kubectl get po
NAME      READY     STATUS    RESTARTS   AGE
kubia-0   1/1       Unknown   0          15m
kubia-1   1/1       Running   0          14m
kubia-2   1/1       Running   0          13m
```  

El Pod sigue estando ahí porque hasta que el control plane puede acceder al kubectl del nodo, no hara el borrado. De echo, antes de que hicieramos nuestro ``delete po kubia-0`` el control plane lo había borrado. Tan pronto kubectl sea capaz de contactar con el control plane, el Pod desaparecera. Si queremos forzar el borrado haremos:  
```
kubectl delete po kubia-0 --force --grace-period 0
```
Ahora si se creara el nuevo Pod:  
```
kubectl get po

NAME          READY     STATUS              RESTARTS   AGE
kubia-0       0/1       ContainerCreating   0          8s
kubia-1       1/1       Running             0          20m
kubia-2       1/1       Running             0          19m
```

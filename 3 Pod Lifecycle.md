# Init Containers
Si necesitamos ejecutar algun setup antes de que el Pod se inicialice podemos definir uno o varios ``initContainers``. Estos contenedores se ejecutarn en serie y pueden hacer tareas como por ejemplo prepopular el contenido de directorios, etc. Un ejemplo:  
```
spec:
  initContainers:                                                        
  - name: init
    image: busybox
    command:
    - sh
    - -c
    - 'while true; do echo "Waiting for fortune service to come up...";  
      wget http://fortune -q -T 1 -O /dev/null >/dev/null 2>/dev/null   
      && break; sleep 1; done; echo "Service is up! Starting main       
      container."'
```
Podemos ver el estado del Pod:  
```
kubectl get po

NAME             READY     STATUS     RESTARTS   AGE
fortune-client   0/1       Init:0/1   0          1m
```
Podemos ver como el pod esta siendo inicializado. Se quedara en este estado indefinidamente porque en nuestro caso la inicialización ejecuta un loop infinito.  
Si miramos el log:  
```
kubectl logs fortune-client -c init

Waiting for fortune service to come up...
```
Además de la opción de lanzar contenedor(es) de inicialización, tenemos otros dos "hooks" en el ciclo de vida:  
- Post Start  
- Pre Stop  

Estos dos "hooks" nos permiten incluir la ejecución de ciertos procedimiento al arrancar un contenedor. Dos puntos a tener en cuenta:  
- Estamos hablando de contenedor. Estos hooks se tienen que incluir en la definición de la imagen dentro del Pod. Estan asociados a un contenedor concreto, no al Pod como era el caso del initContainers.  
- A pesar del nombre, este contenedor no se ejecuta tras el arranque del contenedor, sino al mismo tiempo, ``en paralelo``. Aunque se arranque en paralelo, la ejecución de este hook afectara al contenedor de dos formas:  
  - Hasta que no concluya la ejecución, el estado del contenedor sera ``Waiting``.  
  - Si el hook falla, el contenedor es terminado.  

## Post Start
Podemos ver en la especificación del Pod, ``dentro de la definición de la imagen`` se incluye el hook por medio de la propiedad ``lifecycle``:
```
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-poststart-hook
spec:
  containers:
  - image: luksa/kubia
    name: kubia
    lifecycle:
      postStart:
        exec:                                                              
          command:                                                         
          - sh                                                             
          - -c                                                             
          - "echo 'hook will fail with exit code 15'; sleep 5; exit 15"    

```
## Pre Stop
Se ejecuta inmediatamente antes de que el contenedor termine. Se configura de forma similar al Post Start:  
```
lifecycle:
      preStop:                
        httpGet:              
          port: 8080          
          path: shutdown      
```
A defirencia del Post Start, idenpendientemente de cual sea el resultado de la ejecución del Pre Stop, el contenedor sera eliminado.  
## Matar un contenedor
La condición para que un contenedor sea terminado es que Kubernetes reciba la instrucción de acabar con el Pod. Cuando esto sucede Kubernetes no mata el Pod, lo marca con un timestamp indicando que debe morir. kubctl descubrira la marca, y después de un período de gracia matara el Pod. El período de gracia se puede configurar en el Pod con la propiedad ``spec.terminationGracePeriodSeconds``. El valor por defecto es 30 segundos.  
Cuando kubectl detecta que el Pod debe ser eliminado, ejecuta inmediatamente el Pre Stop script. Cuando el período de gracia haya terminado, el Pod será eliminado, independientemente de lo que haya sucedido con el script the Pre Stop.  

También se puede especificar el perído de gracia al solicitar la eliminación del Pod:  
```
kubectl delete po mypod --grace-period=5
```
Podemos ordenar el borrado inmediatamente del Pod como sigue:  
```
kubectl delete po mypod --grace-period=0 --force
```
__Nota:__ Esta opción puede causar problemas cuando el Pod es stateful, ya que el ResourceController puede crear inmediatamente un Pod de sustitución, lo que podría dar lugar a que haya dos Pods con el mismo nombre corriendo simultáneamente.  
 

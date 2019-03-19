# Kubernetes API server
En la sección anterios terminabamos hablando de la downward api - que no es un REST endpoint!! - como una forma de acceder a los metadatos del Pod. Otra forma de obtener información de contexto es invocando a la api de Kubernetes.  

Podemos ver donde esta expuesta la api preguntando por la información del cluster:  
```
# kubectl cluster-info

Kubernetes master is running at https://192.168.99.100:8443
```
El endpoint esta expuesto via https. Podemos tratar de acceder a él:  
```
# curl https://192.168.99.100:8443 -k
```
La opción ``-k`` de curl hace que no se valide el certificado. Al ejecutar el comando anterior obtendremos un error de autorización, porque para consumir la api necesitamos un token. Podemos evitar la autorización si accedemos a la api por medio del proxy - que kubernetes instala en cada nodo:  
```
# kubectl proxy

Starting to serve on 127.0.0.1:8001
```
Ahora lo intentamos de nuevo:  
```
# curl localhost:8001

{
  "paths": [
    "/api",
    "/api/v1",                  
    "/apis",
    "/apis/apps",
    "/apis/apps/v1beta1",
    ...
    "/apis/batch",              
    "/apis/batch/v1",           
    "/apis/batch/v2alpha1",     
    ...

```
Tenemos acceso a la Kubernetes API. Podemos observar que hay varios recursos disponibles - paths. Si por ejemplo lo intentamos con la /apis/batch:  
```
# curl http://localhost:8001/apis/batch

{
  "kind": "APIGroup",
  "apiVersion": "v1",
  "name": "batch",
  "versions": [
    {
      "groupVersion": "batch/v1",             
      "version": "v1"                         
    },
    {
      "groupVersion": "batch/v2alpha1",       
      "version": "v2alpha1"                   
    }
  ],
  "preferredVersion": {                       
    "groupVersion": "batch/v1",               
    "version": "v1"                           
  },
  "serverAddressByClientCIDRs": null
}
```
Seguimos:  
```
# curl http://localhost:8001/apis/batch/v1

{
  "kind": "APIResourceList",              
  "apiVersion": "v1",
  "groupVersion": "batch/v1",             
  "resources": [                          
    {
      "name": "jobs",                     
      "namespaced": true,                 
      "kind": "Job",                      
      "verbs": [                          
        "create",                         
        "delete",                         
        "deletecollection",               
        "get",                            
        "list",                           
        "patch",                          
        "update",                         
        "watch"                           
      ]
    },
    {
      "name": "jobs/status",              
      "namespaced": true,
      "kind": "Job",
      "verbs": [                          
        "get",                            
        "patch",                          
        "update"                          
      ]
    }
  ]
}
```
Podemos consumir uno de los resources expuestos:  
```
# curl http://localhost:8001/apis/batch/v1/jobs

{
  "kind": "JobList",
  "apiVersion": "batch/v1",
  "metadata": {
    "selfLink": "/apis/batch/v1/jobs",
    "resourceVersion": "225162"
  },
  "items": [
    {
      "metadata": {
        "name": "my-job",
        "namespace": "default",
        ...
```
## Usar el API Server desde un Pod
Creamos un pod de ejemplo para demostrar el uso del API server. El pod usa una imagen que monta curl:  
```
apiVersion: v1
kind: Pod
metadata:
  name: curl
spec:
  containers:
  - name: main
    image: tutum/curl                
    command: ["sleep", "9999999"]    
```
Una vez hemos iniciado el Pod, podemos conectarnos con el - desde su bash - para probar la conectividad con el servidor de API:  
```
# kubectl exec -it curl bash
```
Para averiguar la IP del API server tenemos varias formas:  
- Como el servidor de API se publica como servicio, podemos ver los datos del servicio  
- Como se trata de un servicio más, tendra sus variables de entorno creadas  
- ... y una entrada en el DNS  

Vemos los servicios disponibles:  
```
# kubectl get svc

NAME         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.0.0.1     <none>        443/TCP   46d
...
```
Comprobemos que tenemos nuestras variables de entorno:  
```
# env | grep KUBERNETES_SERVICE

KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_HOST=10.0.0.1
KUBERNETES_SERVICE_PORT_HTTPS=443
```
Tambien se ha creado una entrada en el DNS de Kubernetes:  
```
https://kubernetes
```
Si ahora __desde el pod__ hacemos un curl:  
```
# curl https://kubernetes

curl: (60) SSL certificate problem: unable to get local issuer certificate
...
If you'd like to turn off curl's verification of the certificate, use
  the -k (or --insecure) option
```
Esperado. Como se trata de una petición https se hace la validación del certificado y esta fallando. Podemos usar la opción -k como mostramos antes, o, __configurar el certificado__.  
## Invocar a la api
### Certificado
En cada cluster de Kubernetes hay configurado un secreto que contiene el certificado que necesitamos utilizar, así como el token:  
```
# ls /var/run/secrets/kubernetes.io/serviceaccount/.

ca.crt    namespace    token
```
__Desde nuestro pod__ podemos ejecutar:
```
# curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt https://kubernetes
```
Ahora el error que obtenemos ya no es relativo a la validación del certificado, pero un error de utenticación. Necesitamos pasar el token en la llamada.  
Para evitar tener que especificar ``--cacert``  en todas las llamadas, podemos informar la variable de entorno ``CURL_CA_BUNDLE``:  
```
# export CURL_CA_BUNDLE=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# curl https://kubernetes
```

### Token
Para especificar el token hay que pasar la cabecera ``Authorization``:  
```
# TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# curl -H "Authorization: Bearer $TOKEN" https://kubernetes

{
  "paths": [
    "/api",
    "/api/v1",
    "/apis",
    "/apis/apps",
    "/apis/apps/v1beta1",
    "/apis/authorization.k8s.io",
    ...
    "/ui/",
    "/version"
  ]
}
```
### namespace
Algunas apis requiren como input el namespace en el que esta ejecutandose el Pod. El namespace es el tercero de los valores que podemos encontrar en el secret:  
```
# NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# curl -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/namespaces/$NS/pods


{
  "kind": "PodList",
  "apiVersion": "v1",
  ...
```

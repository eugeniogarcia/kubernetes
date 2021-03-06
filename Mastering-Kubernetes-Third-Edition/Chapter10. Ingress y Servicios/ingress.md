# Instalar el pod de Ingress

Vamos a usar Helm. Actualizamos el hub:

```ps
helm hub update
```

Buscamos el ingress:

```ps
helm search repo ingress

NAME                                    CHART VERSION   APP VERSION     DESCRIPTION
bitnami/nginx-ingress-controller        7.6.1           0.44.0          Chart for the nginx Ingress controller
stable/gce-ingress                      1.2.2           1.4.0           DEPRECATED A GCE Ingress Controller
stable/ingressmonitorcontroller         1.0.50          1.0.47          DEPRECATED - IngressMonitorController chart tha...
stable/nginx-ingress                    1.41.3          v0.34.1         DEPRECATED! An nginx Ingress controller that us...
bitnami/contour                         4.3.1           1.14.1          Contour Ingress controller for Kubernetes
stable/contour                          0.2.2           v0.15.0         DEPRECATED Contour Ingress controller for Kuber...
stable/external-dns                     1.8.0           0.5.14          Configure external DNS servers (AWS Route53, Go...
stable/kong                             0.36.7          1.4             DEPRECATED The Cloud-Native Ingress and API-man...
stable/lamp                             1.1.6           7               DEPRECATED - Modular and transparent LAMP stack...
stable/nginx-lego                       0.3.1                           Chart for nginx-ingress-controller and kube-lego
stable/traefik                          1.87.7          1.7.26          DEPRECATED - A Traefik based Kubernetes ingress...
stable/voyager                          3.2.4           6.0.0           DEPRECATED Voyager by AppsCode - Secure Ingress...
bitnami/kong                            3.5.0           2.3.3           Kong is a scalable, open source API layer (aka ...
```

Vamos a instalar el de nginx:

```ps
helm install mi-ingress bitnami/nginx-ingress-controller
```

Una vez instalado tendremos un servicio - _mi-ingress-nginx-ingress-controller_ - de ingress a traves del cual consumir los servicios de nuestro cluster desde el exterior:

```ps
kubectl get svc

NAME                                                  TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
kubernetes                                            ClusterIP      10.0.0.1       <none>         443/TCP                      6h38m
mi-ingress-nginx-ingress-controller                   LoadBalancer   10.0.237.150   20.74.26.150   80:32632/TCP,443:31193/TCP   6h10m
mi-ingress-nginx-ingress-controller-default-backend   ClusterIP      10.0.243.138   <none>         80/TCP                       6h10m
social-graph-db                                       ClusterIP      10.0.184.159   <none>         5432/TCP                     5h7m
social-graph-manager                                  ClusterIP      10.0.64.254    <none>         9090/TCP                     4h38m
social-graph-manager-pub                              LoadBalancer   10.0.97.177    40.66.58.11    9090:30303/TCP               54m
```

Podemos consumir los servicios en esta direcci�n:

```ps
$Env:SERVICE_IP=$(kubectl get svc --namespace default mi-ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Visit http://${SERVICE_IP} to access your application via HTTP."
echo "Visit https://${SERVICE_IP} to access your application via HTTPS."
```

# Recurso _Ingress_

Explicaci�n de [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/).

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: social-graph-manager
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: www.fgz.com
    http:
      paths:
      - path: /test(/|$)(.*)
        pathType: Prefix
        #pathType: Exact
        backend:
          service:
            name: social-graph-manager
            port:
              number: 9090
```

Con este recurso estamos diciendo que las peticiones que se hagan a _www.fgz.com_, con un prefijo, es decir, que empiecen con _/test(/|$)(.*)_, son procesadas con este ingress. Enviaran la petici�n a un backend, al servicio _http://social-graph-manager:9090/$2_. Al $2 porque hemos indicado la anotaci�n _nginx.ingress.kubernetes.io/rewrite-target: /$2_. $2 hace referencia al segundo componente de la expresi�n regular _/test(/|$)(.*)_. 

Esto significa que si hacemos una petici�n a _http://www.fgz.com/test/follow_, el ingress dirifira esta petici�n a _http://social-graph-manager:9090/follow_.

Podemos a�adir otra definici�n al ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: social-graph-manager
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: www.fgz.com
    http:
      paths:
      - path: /test(/|$)(.*)
        pathType: Prefix
        #pathType: Exact
        backend:
          service:
            name: social-graph-manager
            port:
              number: 9090
      - path: /db
        pathType: Exact
        backend:
          service:
            name: social-graph-db
            port:
              number: 5432		
```

En el segundo path hemos indicado _Exact_, de modo que una petici�n a _http://www.fgz.com/db_ se enrutara a nuestro servicio de postgress.

Podemos ver la definici�n del ingress:

```ps
kubectl describe ingress social-graph-manager

Name:             social-graph-manager
Namespace:        default
Address:          10.240.0.6
Default backend:  default-http-backend:80 (<error: endpoints "default-http-backend" not found>)
Rules:
  Host         Path  Backends
  ----         ----  --------
  www.fgz.com
               /test(/|$)(.*)   social-graph-manager:9090 (10.244.2.4:9090)
               /db              social-graph-db:5432 (10.244.1.5:5432)
Annotations:   kubernetes.io/ingress.class: nginx
               nginx.ingress.kubernetes.io/rewrite-target: /$2
Events:
  Type    Reason  Age                  From                      Message
  ----    ------  ----                 ----                      -------
  Normal  Sync    10s (x10 over 118m)  nginx-ingress-controller  Scheduled for sync
```
# Consumir los servicios

```ps
curl http://www.fgz.com/test/followers/egsmartin

{"followers":{"pupa":true},"err":""}
```

```ps
curl --location --request POST 'http://www.fgz.com/test/follow' \
--header 'Content-Type: text/plain' \
--data-raw '{
    "followed": "egsmartin",
    "follower": "nico"
}'

{"err":""}
```

```ps
curl http://www.fgz.com/test/followers/egsmartin

{"followers":{"nico":true,"pupa":true},"err":""}
```

```ps
curl http://www.fgz.com/test/following/pupa

{"following":{"egsmartin":true},"err":""}
```

```ps
curl --location --request POST 'http://www.fgz.com/test/unfollow' \
--header 'Content-Type: text/plain' \
--data-raw '{
     "followed": "egsmartin",
    "follower": "pupa"
}'

{"err":""}
```

# Network Policy

Lo primero es instalar un plugin CNI que implemente [Network Policies](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/network-policies/). En nuestro caso, con Azure, usaremos Calico. Es __importante destacar, que solo podemos habilitar Calico al crear el Cluster, no se podr� habilitar con un Cluster ya creado__.

Comprobamos que antes de aplicar ninguna policy tenemos:

```ps
curl "http://www.fgz.com/test/followers/egsmartin"
```

Obtenemos una respuesta:

```ps
StatusCode        : 200
StatusDescription : OK
Content           : {"followers":{},"err":""}

RawContent        : HTTP/1.1 200 OK
                    Connection: keep-alive
                    Content-Length: 26
                    Content-Type: text/plain; charset=utf-8
                    Date: Sun, 25 Apr 2021 11:36:36 GMT

                    {"followers":{},"err":""}

Forms             : {}
Headers           : {[Connection, keep-alive], [Content-Length, 26], [Content-Type, text/plain; charset=utf-8], [Date, Sun, 25 Apr
                    2021 11:36:36 GMT]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 26
```

## Deny all

Vamos a aplicar una politica sobre el namespace _default_ que deniegue las comunicaciones entre los pods. De esta forma por defecto no admitimos ning�n trafico de entrada o de salida en pods: 

```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: test-deny
  namespace: default
spec:
  podSelector:
    matchLabels: {}
  policyTypes:
  - Ingress
  - Egress
```

Indicamos que cualquier pod `matchLabels: {}` no admite ni Ingress ni Egress - puesto que no espcificamos ningun origen ni destino en `Ingress` ni `Egress` respectivamente.

Aplicamos la policy:

```ps
kubectl apply -f .\deny-policy.yaml

networkpolicy.networking.k8s.io/test-deny created
```

Verificamos que ya no tenemos acceso:

```ps
curl "http://www.fgz.com/test/followers/egsmartin"
```

Obtenemos un error:

```ps
curl : Unable to connect to the remote server
At line:1 char:1
+ curl "http://www.fgz.com/test/followers/egsmartin"
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-WebRequest], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand
```

## Ingress y Egress

Vamos a habilitar una politica que permite el ingress desde el _ingress nginx_, pasando por el _manager_ y terminando en el _db_. El egress se tiene que permitir desde el _ingress nginx_ hac�a el _manager_. El _db_ no tiene que hacer ninguna llamada

```txt
  ->  ingress nginx  ->  manager  ->  db
  
 a) ingress nginx. Requiere ingress y egress. Lo vamos a permitir a cualquier puerto y protocolo
 b) manager. Requiere ingress y egress. El ingress solo es el puerto 9090, y el egress al 5432
 c) db. Solo require ingress por el 5432
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: entrada-a-nginx
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance : mi-ingress
  ingress:
  - {}
  policyTypes:
  - Ingress
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: entrada-a-manager
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: manager
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/instance : mi-ingress
    ports:
    - port: 9090
      protocol: TCP
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: entrada-a-db
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: postgres
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: manager
    ports:
    - port: 5432
      protocol: TCP
```

- A los pods `app.kubernetes.io/instance : mi-ingress` se les permite cualquier Ingress `{}`
- A los pods `role: manager` se les permite el Ingress via `TCP` al puerto `9090`
- A los pods `role: postgres` se les permite el Ingress via `TCP` al puerto `5432`

__NOTA:__ Tambi�n podemos usar el namespace como filtro, de modo que por ejemplo, podemos permitir o no el acceso desde pods de un namespace, a pods de otro namespace. Aqu� como no hemos indicado nada, la politica se aplica sobre el namespace en el que esta creada - que en nuestro caso es _default_.

### Egress

```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: salida-desde-nginx
  namespace: default
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance : mi-ingress
  egress:
  - {}
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: salida-desde-manager
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: manager
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: postgres
    ports:
    - port: 5432
      protocol: TCP
```

- A los pods `app.kubernetes.io/instance : mi-ingress` se les permite cualquier Egress `{}`
- A los pods `role: manager` se les permite el Egress via `TCP` al puerto `5432`

__NOTA:__ Tambi�n podemos usar el namespace como filtro, de modo que por ejemplo, podemos permitir o no el acceso desde pods de un namespace, a pods de otro namespace. Aqu� como no hemos indicado nada, la politica se aplica sobre el namespace en el que esta creada - que en nuestro caso es _default_.
### Prueba

Aplicamos las policies:

```ps
kubectl apply -f .\policy-egress.yaml

kubectl apply -f .\policy-ingress.yaml
```

y comprobamos que ahora si tenemos acceso:

```ps
curl "http://www.fgz.com/test/followers/egsmartin"
```

Obtenemos una respuesta:

```ps
StatusCode        : 200
StatusDescription : OK
Content           : {"followers":{},"err":""}

RawContent        : HTTP/1.1 200 OK
                    Connection: keep-alive
                    Content-Length: 26
                    Content-Type: text/plain; charset=utf-8
                    Date: Sun, 25 Apr 2021 11:36:36 GMT

                    {"followers":{},"err":""}

Forms             : {}
Headers           : {[Connection, keep-alive], [Content-Length, 26], [Content-Type, text/plain; charset=utf-8], [Date, Sun, 25 Apr
                    2021 11:36:36 GMT]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 26
```

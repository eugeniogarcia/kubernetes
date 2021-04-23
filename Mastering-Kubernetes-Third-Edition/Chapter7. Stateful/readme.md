# 1. Config Map

Podemos mapear los valores del config-map como un volumen más, o como variables de entorno. Veamos en este ejemplo como funcionaría con variables de entorno:

```ps
kubectl apply -f .\1_db-config-map.yaml

kubectl apply -f .\1_pod-with-db.yaml
```

Podemos ver que efectivamente los datos del config-map aparecen como la variable de entorno *DB_IP_ADDRESSES*:

```ps
kubectl logs some-pod

KUBERNETES_PORT=tcp://10.96.0.1:443
KUBERNETES_SERVICE_PORT=443
HOSTNAME=some-pod
SHLVL=1
HOME=/root
DB_IP_ADDRESSES=1.2.3.4,5.6.7.8
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_SERVICE_HOST=10.96.0.1
PWD=/
```

# 2. Stateful Set

Necesitamos varias cosas:
- Un headless service. Proporcionará la identidad de los pods

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
    - port: 80
      name: web
  clusterIP: None
  selector:
    app: nginx
```

Creamos el servicio:

```ps
kubectl apply -f .\2_nginx-headless-service.yaml
service/nginx created
```

Vemos como efectivamente no tiene una ip asignada, es _headless_:

```ps
kubectl get svc

NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   14h
nginx        ClusterIP   None         <none>        80/TCP    11s
```

- El Statefull set, que define el número de replicas a utilizar. Creamos el stateful set:

```ps
kubectl apply -f .\2_nginx-stateful-set.yaml
```

- Almacenamiento persistente (parte de la definición del pod):

```yaml
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 50Mi
```

Podemos ver que el PV se ha creado dinámicamente. También podemos ver que se han creado los PVC y que se han asociado al PV. 

```ps
kubectl get pv

NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   
pvc-4fedb0b0-50e0-4075-b876-72474028727a   50Mi       RWO            Delete           Bound    
pvc-72c85281-7799-4e4a-abcd-c5f5606dafd2   50Mi       RWO            Delete           Bound    
pvc-89a2a13d-4691-42cb-9f00-62a07e813c55   50Mi       RWO            Delete           Bound    

```ps
kubectl get pvc

NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   
www-nginx-0   Bound    pvc-4fedb0b0-50e0-4075-b876-72474028727a   50Mi       RWO            
www-nginx-1   Bound    pvc-72c85281-7799-4e4a-abcd-c5f5606dafd2   50Mi       RWO            
www-nginx-2   Bound    pvc-89a2a13d-4691-42cb-9f00-62a07e813c55   50Mi       RWO            
```

El PV se creo dinámicamente porque el _addmission controller_ tiene el plugin _a_ activado:

```ps
['kube-apiserver', '--advertise-address=172.17.53.204', '--allow-privileged=true', '--authorization-mode=Node,RBAC', '--client-ca-file=/var/lib/minikube/certs/ca.crt', '--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota', ...]
```

## 2.1 CoreDNS y los servicios headless

CoreDNS asignará a cada pod asociado al servicio un _A record_ en la zona. También se definirá un servicio en la zona. Cuando un pod quiera referirse al servicio, se consultará al DNS para la resolución. CoreDNS tiene que monitorizar en el API Server cualquier cambio en los end-points para mantener la configuración de la zona actualizada.

Para analizar qué es lo que hace CoreDNS vamos a necesitar usar las utilidades dns. Las tenemos configuradas en la siguiente imagen que definimos en este pod:

```ps
kubectl apply -f .\2_dns_debug.yaml
```

Nos conectamos a la image para usar las herramientas. Lo primero es ver que nuestro CoreDNS resuelve el nombre del cluster:

```ps
kubectl exec -i -t dnsutils -- nslookup kubernetes.default

Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   kubernetes.default.svc.cluster.local
Address: 10.96.0.1
```

Podemos ver que todos los pods que se crean, incluido el que estamos usando con las herramientas DNS, se configuran apuntando al DNS del cluster, a nuestro CoreDNS:

```ps
kubectl exec -ti dnsutils -- cat /etc/resolv.conf

nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

POdemos ver que cuando el pod que implementa CoreDNS arrancó, el arranque fue correcto:

```ps
kubectl logs --namespace=kube-system -l k8s-app=kube-dns

.:53
[INFO] plugin/reload: Running configuration MD5 = db32ca3650231d74073ff4cf814959a7
CoreDNS-1.7.0
linux/amd64, go1.14.4, f59c03d
```

Podemos ver que se instancia un servicio en el cluster que expone el end-point de CoreDNS. Notese como se abre el puerto 53 en udp y tcp:

```ps
kubectl get svc --namespace=kube-system

NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   15h
```

Una vez hemos comprobado que CoreDNS se ha configurado correctamente en el cluster, podemos ver como se resuelve nuestro headless service:

```ps
kubectl exec -i -t dnsutils -- dig nginx.default.svc.cluster.local

; <<>> DiG 9.11.6-P1 <<>> nginx.default.svc.cluster.local
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 65459
;; flags: qr aa rd; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
; COOKIE: a47a63e991bd95a4 (echoed)
;; QUESTION SECTION:
;nginx.default.svc.cluster.local. IN    A

;; ANSWER SECTION:
nginx.default.svc.cluster.local. 30 IN  A       172.18.0.4
nginx.default.svc.cluster.local. 30 IN  A       172.18.0.5
nginx.default.svc.cluster.local. 30 IN  A       172.18.0.3

;; Query time: 0 msec
;; SERVER: 10.96.0.10#53(10.96.0.10)
;; WHEN: Fri Apr 09 08:17:30 UTC 2021
;; MSG SIZE  rcvd: 213
```

Observamos que no hay un A record para el headless service, porque no hay una vip asociada a él. En su lugar el plugin de CoreDNS inspecciona el ip-range del servicio y crea una entrada, un A record para cada IP, y les asocia el nombre del servicio. Creara también un servicio http y udp. Esto significa que con el headless service, __CoreDNS tiene que subscribise con el API Server para enterarse de cualquier cambio en el ip-range del servicio, y reacciones quitando o añadiendo entradas en la zona__.

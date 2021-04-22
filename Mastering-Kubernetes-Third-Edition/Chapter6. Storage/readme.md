# emptyDir

El almacenamiento se provisiona a nivel de contenedor/pod.

```ps
kubectl apply -f .\1_hue-scheduler.yaml
```

Creara un pod con dos contenedores. Veamos como tienen dos puntos de montaje que apuntan al mismo volumen: 

```ps
kubectl exec -it hue-scheduler -c hue-global-listener -- touch /notifications/archivo

kubectl exec -it hue-scheduler -c hue-job-scheduler -- ls /incoming
archivo
```

# HostPath

El almacenamiento se provisiona a nivel de host. Esto nos permitira hacer comunicación __intranodo__. Los datos será persistentes cuando un pod muera y se schedule en el mismo nodo - esto dificilmente se puede garantizar, salvo en el caso de daemonsets, o que se use node afinity a un nodo específico.

```ps
kubectl apply -f .\2_pod-with-hostpath.yaml

kubectl apply -f .\2_pod-with-hostpath1.yaml

kubectl exec -it the-pod-withhost -- touch /mnt/data/b

kubectl exec -it the-pod-withhost1 -- ls /mnt/data
b
```

Para poder escribir se tiene que tener permisos sobre el host. En nuestro caso los tenemos porque estamos ejecutando como root. Sino fuera así habría que dar al contenedor privilegios

```ps
kubectl exec -it the-pod-withhost1 -- bash

root@the-pod-withhost1:/# id
uid=0(root) gid=0(root) groups=0(root)
```

```yaml
- image: the\_g1g1/hue-coupon-hunter
  name: hue-coupon-hunter
  volumeMounts:
  - mountPath: /coupons
    name: coupons-volume
  securityContext:
    privileged: true
```

# Persistent Volumes

Con este tipo de volumenes garantizamos persistencia incluso cuando un nodo muere. Este almacenamiento esta pensado para Daemonsets.

En este tipo de volumenes hay que especificar una clase de almacenamiento. El papel de la clase de almacenamiento es el de provisionar el disco - en azure se ofrecen dos clases de almacenamiento dinámico que automatizan la creación de un recurso de disco, y lo montan.

Hay dos partes para crear el volumen:
- Persistent Volume (PV). Se indican todos los datos (tipo, capacidad, modo de acceso, ...)
  - Estático. Se crea manualmente por un administrador en el nodo. Se especifica el punto de montaje
  - Dinámico. La clase de almancenamiento automatiza el proceso
- Persistent Volume Claim (PVC). El desarrollador crea este recurso con las características que se necesitan para el nodo. En el nodo se indica el Persistent Volume Claim

Kubernetes asociara el PVC al PV

```ps
kubectl apply -f .\3_local-storage-class.yaml
storageclass.storage.k8s.io/local-storage created

kubectl apply -f .\3_local-volume.yaml
persistentvolume/local-pv created

kubectl get pv
NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    
local-pv   100Mi      RWO            Delete           Available           local-storage
```

Es importante destacar que el PV tiene que tener una especificación de `nodeAffinity`. En este caso hemos indicado que el nodo se llame `minikube`. La clase que estamos usando, requiere que hayamos creado el punto de montaje `/mnt/disks/disk-1` previamente.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
  labels:
    release: stable
    capacity: 100Mi
spec:
  capacity:
    storage: 100Mi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/disk-1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - minikube
```

Cuando hablamos de `accessModes` 
- RWO: ReadWriteOnce
- ROX: ReadOnlyMany
- RWX: ReadWriteMany

Hay que destacar que cuando el modo es Many indica que varios Pods pueden usar el volumen. Siempre desde el mismo nodo.

El PVC:

```ps
kubectl apply -f .\3_local-persistent-volume-claim.yaml
persistentvolumeclaim/local-storage-claim created

kubectl get pvc
NAME                  STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS    AGE
local-storage-claim   Pending                                      local-storage   8s

kubectl get pv
NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    
local-pv   100Mi      RWO            Delete           Available           local-storage
```
![Components.png](Imagenes\Components.png)  

Status of the components:  

```
kubectl get componentstatuses

NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
```

Kubernetes system components communicate only with the API server. They don’t talk to each other directly. The API server is the only component that communicates with etcd.  

Connections between the API server and the other components are almost always initiated by the components, as shown in figure. But the API server does connect to the Kubelet when you use kubectl to fetch logs, use kubectl attach to connect to a running container, or use the kubectl port-forward command.  

__The components on the worker nodes all need to run on the same node, the components of the Control Plane can easily be split across multiple servers__.  

While __multiple instances of etcd and API server can be active at the same time__ and do perform their jobs in parallel, __only a single instance of the Scheduler and the Controller Manager may be active at a given time__.  

The __Control Plane components, as well as kube-proxy, can either be deployed on the system directly or they can run as pods__. __The Kubelet is the only component that always runs as a regular system component, and it’s the Kubelet that then runs all the other components as pods__. To run the Control Plane components as pods, the Kubelet is also deployed on the master:  
```
kubectl get po -o custom-columns=POD:metadata.name,NODE:spec.nodeName
  --sort-by spec.nodeName -n kube-system

POD                              NODE
kube-controller-manager-master   master      
kube-dns-2334855451-37d9k        master      
etcd-master                      master      
kube-apiserver-master            master      
kube-scheduler-master            master      

kube-flannel-ds-tgj9k            node1       
kube-proxy-ny3xm                 node1       
kube-flannel-ds-0eek8            node2       
kube-proxy-sp362                 node2       
kube-flannel-ds-r5yf4            node3       
kube-proxy-og9ac                 node3       
```
We can see which components do run on the master and which ones on the worker nodes. All the Control Plane components are running as pods on the master node. There are three worker nodes, and each one runs the kube-proxy and a Flannel pod, which provides the overlay network for the pods.  
# etcd
All the objects you’ve created, ReplicationControllers, Services, Secrets, and so on—need to be stored somewhere in a persistent manner so their manifests survive API server restarts and failures. Kubernetes uses etcd, which is a fast, distributed, and consistent key-value store. Because it’s distributed, __you can run more than one etcd instance to provide both high availability and better performance__.  

The only component that talks to etcd directly is the Kubernetes API server. All other components read and write data to etcd indirectly through the API server. It uses optimistic locking system as well as validation. All other Control Plane components to go through the API server. This way updates to the cluster state are always consistent, because the optimistic locking mechanism is implemented in a single place, so less chance exists.  

## Optimistic Locking
Optimistic concurrency control is a method where instead of locking a piece of data and preventing it from being read or updated while the lock is in place, the piece of data includes a version number. Every time the data is updated, the version number increases. When updating the data, the version number is checked to see if it has increased between the time the client read the data and the time it submits the update. If this happens, the update is rejected and the client must re-read the new data and try to update it again.  

The result is that when two clients try to update the same data entry, only the first one succeeds.  

All Kubernetes resources include a metadata.resourceVersion field, which clients need to pass back to the API server when updating an object. If the version doesn’t match the one stored in etcd, the API server rejects the update.  
## Structure
The keys are stored in etcd as if they were directories (in etcd v2 they are actually stored as directories; not anymore in v3). Each key stores a type of resources:  

```
$ etcdctl ls /registry

/registry/configmaps
/registry/daemonsets
/registry/deployments
/registry/events
/registry/namespaces
/registry/pods

(...)
```
__Note__: ``If you’re using v3 of the etcd API, you can’t use the ls command to see the contents of a directory. Instead, you can list all keys that start with a given prefix with etcdctl get /registry --prefix=true``  
## Clustering
For ensuring high availability, you’ll usually run more than a single instance of etcd. Multiple etcd instances will need to remain consistent. Such a distributed system needs to reach a consensus on what the actual state is. etcd uses the RAFT consensus algorithm to achieve this. Each node’s state is either what the majority of the nodes agrees is the current state or is one of the previously agreed upon states.  

![Raft.png](Imagenes\Raft.png)

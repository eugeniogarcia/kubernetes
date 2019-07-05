Kubernetes allows you to affect where pods are scheduled. Initially, this was only done by specifying a node selector in the pod specification.

# Using taints and tolerations to repel pods from certain nodes
Pods’ tolerations of those taints. They’re used for restricting which pods can use a certain node.  

Node selectors and node affinity rules make it possible to select which nodes a pod can or can’t be scheduled to by specifically adding that information to the pod, __whereas taints allow rejecting deployment of pods to certain nodes__ by only adding taints to the node without having to modify existing pods. __Pods that you want deployed on a tainted node need to opt in to use the node__. You can see the node’s taints using kubectl describe node:  

```
kubectl describe node master.k8s

Name:         master.k8s
Role:
Labels:       beta.kubernetes.io/arch=amd64
              beta.kubernetes.io/os=linux
              kubernetes.io/hostname=master.k8s
              node-role.kubernetes.io/master=
Annotations:  node.alpha.kubernetes.io/ttl=0
              volumes.kubernetes.io/controller-managed-attach-detach=true
Taints:       node-role.kubernetes.io/master:NoSchedule                    1
...
```

Taints have a key, value, and an effect, and are represented as <key>=<value>:<effect>. The master node’s taint shown in the previous listing has the key node-role.kubernetes.io/master, a null value (not shown in the taint), and the effect of NoSchedule. __This taint prevents pods from being scheduled to the master node, unless those pods tolerate this taint__.  

To make sure the kube-proxy pod also runs on the master node, it includes the appropriate toleration.  
```
kubectl describe po kube-proxy-80wqm -n kube-system

...
Tolerations:    node-role.kubernetes.io/master=:NoSchedule
                node.alpha.kubernetes.io/notReady=:Exists:NoExecute
                node.alpha.kubernetes.io/unreachable=:Exists:NoExecute
...
```
As you can see, the first toleration matches the master node’s taint, allowing this kube-proxy pod to be scheduled to the master node.  

The two other tolerations on the kube-proxy pod define how long the pod is allowed to run on nodes that aren’t ready or are unreachable.  
Each taint has an effect associated with it. Three possible effects exist:
- `NoSchedule`, which means pods won’t be scheduled to the node if they don’t tolerate the taint.
- `PreferNoSchedule` is a soft version of NoSchedule, meaning the scheduler will try to avoid scheduling the pod to the node, but will schedule it to the node if it can’t schedule it somewhere else.
- `NoExecute`, unlike NoSchedule and PreferNoSchedule that only affect scheduling, __also affects pods already running on the node__. If you add a NoExecute taint to a node, pods that are already running on that node and don’t tolerate the NoExecute taint will be evicted from the node.  

To add a taint, you use __the kubectl taint command__:  
```
kubectl taint node node1.k8s node-type=production:NoSchedule  
```

This adds a taint with key node-type, value production and the NoSchedule effect.  

To deploy production pods to the production nodes, they need to tolerate the taint you added to the nodes.  
```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: prod
spec:
  replicas: 
  template:
    spec:
      ...
      tolerations:
      - key: node-type         
        Operator: Equal        
        value: production      
        effect: NoSchedule     
```

Nodes can have more than one taint and pods can have more than one toleration. As you’ve seen, taints can only have a key and an effect and don’t require a value. Tolerations can tolerate a specific value by specifying the Equal operator.  

Taints can be used to prevent scheduling of new pods (NoSchedule effect) and to define unpreferred nodes (PreferNoSchedule effect) and even evict existing pods from a node (NoExecute). You can also use a toleration to specify __how long Kubernetes should wait before rescheduling a pod to another node if the node the pod is running on becomes unready or unreachable__.  

You can also use a toleration to specify how long Kubernetes should wait before ___rescheduling a pod to another node__ if the node the pod is running on becomes unready or unreachable.  

```
kubectl get po prod-350605-1ph5h -o yaml

...
  tolerations:
  - effect: NoExecute                              1
    key: node.alpha.kubernetes.io/notReady         1
    operator: Exists                               1
    tolerationSeconds: 300                         1
  - effect: NoExecute                              2
    key: node.alpha.kubernetes.io/unreachable      2
    operator: Exists                               2
    tolerationSeconds: 300                         2
```
- 1 The pod tolerates the node being notReady for 300 seconds, before it needs to be rescheduled.
- 2 The same applies to the node being unreachable.  

The Kubernetes Control Plane, when it detects that a node is no longer ready or no longer reachable, will wait for 300 seconds before it deletes the pod and reschedules it to another node.

# Using node affinity to attract pods to certain nodes
Taints are used to keep pods away from certain nodes. Affinity allows you to tell Kubernetes to schedule pods only to specific subsets of nodes.  

Node selectors will eventually be deprecated, so it’s important you understand the new node affinity rules.  
```
kubectl describe node gke-kubia-default-pool-db274c5a-mjnf
Name:     gke-kubia-default-pool-db274c5a-mjnf
Role:
Labels:   beta.kubernetes.io/arch=amd64
          beta.kubernetes.io/fluentd-ds-ready=true
          beta.kubernetes.io/instance-type=f1-micro
          beta.kubernetes.io/os=linux
          cloud.google.com/gke-nodepool=default-pool
          failure-domain.beta.kubernetes.io/region=europe-west1         1
          failure-domain.beta.kubernetes.io/zone=europe-west1-d         1
          kubernetes.io/hostname=gke-kubia-default-pool-db274c5a-mjnf   1
```
- 1 These three labels are the most important ones related to node affinity

The node has many labels, but the last three are the most important when it comes to node affinity and pod affinity, which you’ll learn about later:  
- failure-domain.beta.kubernetes.io/region specifies __the geographical region the node is__ located in.
- failure-domain.beta.kubernetes.io/zone specifies the availability zone the node is in.
- kubernetes.io/hostname is obviously the node’s hostname.  

These and other labels can be used in pod affinity rules.  
```
apiVersion: v1
kind: Pod
metadata:
  name: kubia-gpu
spec:
  nodeSelector:          1
    gpu: "true"          1
  ...
```
The nodeSelector field specifies that the pod should only be deployed on nodes that include the gpu=true label. If you replace the node selector with a node affinity rule, the pod definition will look like the following listing:  

```
apiVersion: v1
kind: Pod
metadata:
  name: kubia-gpu
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: gpu
            operator: In
            values:
            - "true"
```

This is much more complicated than a simple node selector.  
- requiredDuringScheduling... means the rules defined under this field specify the labels the node must have for the pod to be scheduled to the node.
- ...IgnoredDuringExecution means the rules defined under the field don’t affect pods already executing on the node  

Affinity currently only affects pod scheduling and never causes a pod to be evicted from a node. Eventually, Kubernetes will also support RequiredDuringExecution, which means that if you remove a label from a node, pods that require the node to have that label will be evicted from such a node.  

![Afinity.png](.\Imagenes\Afinity.png)

The biggest benefit of the newly introduced node affinity feature is the ability to specify which nodes the Scheduler should prefer when scheduling a specific pod. This is done through the `preferredDuringSchedulingIgnoredDuringExecution` field.  

Imagine having multiple datacenters across different countries. Each datacenter represents a separate availability zone. You now want to deploy a few pods and you’d prefer them to be scheduled to zone1 and to the machines reserved for your company’s deployments. If those machines don’t have enough room for the pods or if other important reasons exist that prevent them from being scheduled there, you’re okay with them being scheduled to the machines your partners use and to the other zones.  

First, the nodes need to be labeled appropriately:  

```
kubectl label node node1.k8s availability-zone=zone1
kubectl label node node1.k8s share-type=dedicated
kubectl label node node2.k8s availability-zone=zone2
kubectl label node node2.k8s share-type=shared
kubectl get node -L availability-zone -L share-type
```

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: pref
spec:
  template:
    ...
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:    
          - weight: 80                                        
            preference:                                       
              matchExpressions:                               
              - key: availability-zone                        
                operator: In                                  
                values:                                       
                - zone1                                       
          - weight: 20                                        
            preference:                                       
              matchExpressions:                               
              - key: share-type                               
                operator: In                                  
                values:                                       
                - dedicated                                   
      ...
```
You’re defining a node affinity preference, instead of a hard requirement. If your cluster had many nodes, when scheduling the pods of the Deployment in the previous listing, the nodes would be split into four groups:  

![AfinityExt.png](\Imagenes\AfinityExt.png)

If you create this Deployment in your two-node cluster, you should see most (if not all) of your pods deployed to node1.  
```
kubectl get po -o wide

NAME                READY   STATUS    RESTARTS  AGE   IP          NODE
pref-607515-1rnwv   1/1     Running   0         4m    10.47.0.1   node2.k8s
pref-607515-27wp0   1/1     Running   0         4m    10.44.0.8   node1.k8s
pref-607515-5xd0z   1/1     Running   0         4m    10.44.0.5   node1.k8s
pref-607515-jx9wt   1/1     Running   0         4m    10.44.0.4   node1.k8s
pref-607515-mlgqm   1/1     Running   0         4m    10.44.0.6   node1.k8s
```

That besides the node affinity prioritization function, the Scheduler also uses other prioritization functions to decide where to schedule a pod. One of those is the Selector-SpreadPriority function, which makes sure pods belonging to the same ReplicaSet or Service are spread around different nodes so a node failure won’t bring the whole service down

# Co-locating pods with pod affinity and anti-affinity
You’ll deploy a backend pod and five frontend pod replicas with pod affinity configured so that they’re all deployed on the same node as the backend pod.  

```
kubectl run backend -l app=backend --image busybox -- sleep 999999
```

This Deployment is not special in any way. The only thing you need to note is the app=backend label you added to the pod using the __-l option__.  

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 5
  template:
    ...
    spec:
      affinity:
        podAffinity:                                        
          requiredDuringSchedulingIgnoredDuringExecution:   
          - topologyKey: kubernetes.io/hostname             
            labelSelector:                                  
              matchLabels:                                  
                app: backend                                
      ...
```

![CoLocation.png](.\Imagenes\CoLocation.png)

What’s interesting is that if you now delete the backend pod, the Scheduler will schedule the pod to node2 even though it doesn’t define any pod affinity rules itself (the rules are only on the frontend pods). This makes sense, because otherwise if the backend pod were to be deleted by accident and rescheduled to a different node, the frontend pods’ affinity rules would be broken.  

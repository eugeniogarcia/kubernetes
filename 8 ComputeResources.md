# Introduction
When creating a pod, you can specify the amount of CPU and memory that a container needs (these are called requests) and a hard limit on what it may consume (known as limits). They’re specified for each container individually, not for the pod as a whole.
```
apiVersion: v1
kind: Pod
metadata:
  name: requests-pod
spec:
  containers:
  - image: busybox
    command: ["dd", "if=/dev/zero", "of=/dev/null"]
    name: main              1
    resources:              1
      requests:             1
        cpu: 200m           2
        memory: 10Mi        3
```

- 1 You’re specifying resource requests for the main container.
- 2 The container requests 200 millicores (that is, 1/5 of a single CPU core’s time).
- 3 The container also requests 10 mebibytes of memory.  

In the pod manifest, your single container requires one-fifth of a CPU core (200 millicores) to run properly. Five such pods/containers can run sufficiently fast on a single CPU core.
When you don’t specify a request for CPU, you’re saying you don’t care how much CPU time the process running in your container is allotted. In the worst case, it may not get any CPU time at all. You’re also requesting 10 mebibytes of memory for the container. Might use less, but you’re not expecting them to use more than that in normal circumstances.  

When the pod starts, you can take a quick look at the process’ CPU consumption by running the top command inside the container, as shown in the following listing:  

```
kubectl exec -it requests-pod top

Mem: 1288116K used, 760368K free, 9196K shrd, 25748K buff, 814840K cached
CPU:  9.1% usr 42.1% sys  0.0% nic 48.4% idle  0.0% io  0.0% irq  0.2% sirq
Load average: 0.79 0.52 0.29 2/481 10
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    1     0 root     R     1192  0.0   1 50.2 dd if /dev/zero of /dev/null
    7     0 root     R     1200  0.0   0  0.0 top
```

The __dd command__ you’re running in the container consumes as much CPU as it can, but it only runs a single thread so it __can only use a single core__. __The Minikube VM, which is where this example is running, has two CPU cores allotted to it. That’s why the process is shown consuming 50% of the whole CPU__. Which means the __container is using more than the 200 millicores you requested in the pod__ specification. This is expected, because requests don’t limit the amount of CPU a container can use. You’d need to specify a CPU limit to do that.  

# How resource requests affect scheduling
By specifying resource requests, you’re specifying __the minimum amount of resources your pod needs__. This information is what the Scheduler uses when scheduling the pod to a node. __Each node has a certain amount of CPU and memory__ it can allocate to pods. Scheduler will only consider nodes with enough unallocated resources to meet the pod’s resource requirements.  

The Scheduler doesn’t look at how much of each individual resource is being used at the exact time of scheduling but at the sum of resources requested by the existing pods deployed on the node. Three pods are deployed on the node. Together, they’ve requested 80% of the node’s CPU and 60% of the node’s memory. Pod D, shown at the bottom right of the figure, cannot be scheduled onto the node because it requests 25% of the CPU. __The fact that the three pods are currently using only 70% of the CPU makes no difference__.  

![ResSched.png](.\Imagenes\ResSched.png)

The Scheduler first filters the list of nodes to exclude those that the pod can’t fit on and then prioritizes the remaining nodes per the configured prioritization functions. Among others, two prioritization functions rank nodes based on the amount of resources:  

- LeastRequestedPriority. Prefers nodes with fewer requested resources
- MostRequestedPriority. The exact opposite  

They both __consider the amount of requested resources__, __not the amount of resources actually consumed__.  

## Inspecting a node’s capacity
```
kubectl describe nodes
Name:       minikube
...
Capacity:                         1
  cpu:           2                1
  memory:        2048484Ki        1
  pods:          110              1
Allocatable:                      2
  cpu:           2                2
  memory:        1946084Ki        2
  pods:          110              2
...
```

The capacity represents the total resources of a node, which may not all be available to pods. Certain resources may be reserved for Kubernetes and/or system components. __The Scheduler bases its decisions only on the allocatable resource amounts__.  

```
kubectl describe po requests-pod-3
Name:       requests-pod-3
Namespace:  default
Node:       /                                                1
...
Conditions:
  Type           Status
  PodScheduled   False                                       2
...
Events:
... Warning  FailedScheduling    No nodes are available      3
                                 that match all of the       3
                                 following predicates::      3
                                 Insufficient cpu (1).       3
```

- 1 No node is associated with the pod.
- 2 The pod hasn’t been scheduled.
- 3 Scheduling has failed because of insufficient CPU.  

The output shows that the pod hasn’t been scheduled because it can’t fit on any node due to insufficient CPU on your single node.  

## Freeing resources to get the pod scheduled
The pod will only be scheduled when an adequate amount of CPU is freed. If you delete your second pod, the Scheduler will be notified of the deletion and will schedule your third pod as soon as the second pod terminates.  

## Understanding how CPU requests affect CPU time sharing
You now have two pods running in your cluster. One has requested 200 millicores and the other one five times as much. You haven’t defined any limits yet, so the two pods are in no way limited when it comes to how much CPU they can each consume.  

The CPU requests don’t only affect scheduling—they also determine how the remaining (unused) CPU time is distributed between pods. Because your first pod requested 200 millicores of CPU and the other one 1,000 millicores, any unused CPU will be split among the two pods in a 1 to 5 ratio.  

![ShareCPU.png](.\Imagenes\ShareCPU.png)

But __if one container wants to use up as much CPU as it can, while the other one is sitting idle__ at a given moment, __the first container will be allowed to use the whole CPU time__ (minus the small amount of time used by the second container, if any). After all, it makes sense to use all the available CPU if no one else is using it, right? __As soon as the second container needs CPU time, it will get it__ and the first container will be throttled back.  

## Defining and requesting custom resources
Kubernetes also allows you to add your own custom resources to a node and request them in the pod’s resource requests. We need to make Kubernetes aware of your custom resource by adding it to the Node object’s capacity field. This can be done by performing a PATCH HTTP request. __The resource name can be anything__, such as example.org/my-resource, as long as it doesn’t start with the kubernetes.iodomain. The __quantity must be an integer__ (for example, you can’t set it to 100 millis, because 0.1 isn’t an integer; but you can set it to 1000m or 2000m or, simply, 1 or 2).  

when creating pods, you specify the same resource name and the requested quantity under the resources.requests field in the container spec or with --requests when using kubectl run like you did in previous examples. The Scheduler will make sure the pod is only deployed to a node that has the requested amount of the custom resource available. Every deployed pod obviously reduces the number of allocatable units of the resource.  

An example of a custom resource could be the number of GPU units available on the node.  

# Limiting resources available to a container
You may want to prevent certain containers from using up more than a specific amount of CPU. And you’ll always want to limit the amount of memory a container can consume. __CPU is a compressible resource__, which means the amount used by a container can be throttled without affecting the process running in the container in an adverse way. __Memory is__ obviously different—it’s __incompressible__. Once a process is given a chunk of memory, that memory can’t be taken away from it until it’s released by the process itself. That’s why you need to limit the maximum amount of memory a container can be given.  

Without limiting memory, a container (or a pod) running on a worker node may eat up all the available memory and affect all other pods on the node and any new pods scheduled to the node.  
```
apiVersion: v1
kind: Pod
metadata:
  name: limited-pod
spec:
  containers:
  - image: busybox
    command: ["dd", "if=/dev/zero", "of=/dev/null"]
    name: main
    resources:             1
      limits:              1
        cpu: 1             2
        memory: 20Mi       3
```
Because you haven’t specified any resource requests, they’ll be set to the same values as the resource limits.  

__Unlike resource requests__, resource __limits aren’t constrained by the node’s allocatable resource amounts__. __The sum of all limits of all the pods on a node is allowed to exceed 100% of the node’s capacity__. when 100% of the node’s resources are used up, certain containers will need to be killed.   

When a process tries to allocate memory over its limit, the process is killed (it’s said the container is __OOMKilled__, where OOM stands for Out Of Memory). If the pod’s restart policy is set to Always or OnFailure, the process is restarted immediately, so you may not even notice it getting killed. But if it keeps going over the memory limit and getting killed, Kubernetes will begin restarting it with increasing delays between restarts. You’ll see a __CrashLoopBackOff status__ in that case.  

```
kubectl get po

NAME        READY     STATUS             RESTARTS   AGE
memoryhog   0/1       CrashLoopBackOff   3          1m
```  

The CrashLoopBackOff status doesn’t mean the Kubelet has given up. It means that __after each crash__, the __Kubelet is increasing the time period before restarting the container__. After the first crash, it restarts the container immediately and then, __if it crashes again, waits for 10 seconds__ before restarting it again. On __subsequent crashes, this delay is then increased exponentially to 20, 40, 80, and 160 seconds__, and finally limited to 300 seconds. Once the interval hits the 300-second limit, the Kubelet keeps restarting the container indefinitely every five minutes until the pod either stops crashing or is deleted.  

## Understanding how apps in containers see limits
The pod’s CPU limit is set to 1 core and its memory limit is set to 20 MiB.  

The top command shows the memory amounts of the whole node the container is running on. __Even though you set a limit__ on how much memory is available to a __container__, __the container will not be aware of this limit__.  

The problem is visible when running Java apps, especially if you don’t specify the maximum heap size for the Java Virtual Machine with the -Xmx option. In that case, the JVM will set the maximum heap size based on the host’s total memory instead of the memory available to the container. When you run your containerized Java apps in a Kubernetes cluster on your laptop, the problem doesn’t manifest itself, because the difference between the memory limits you set for the pod and the total memory available on your laptop is not that great.  

But __when you deploy your pod onto a production system__, where nodes have much more physical memory, __the JVM may go over the container’s memory limit you configured and will be OOMKilled__.  

And if you think setting the __-Xmx option__ properly solves the issue, you’re wrong, unfortunately. The -Xmx option only constrains the heap size, but __does nothing about the JVM’s off-heap memory__. Luckily, new versions of Java alleviate that problem by taking the configured container limits into account.  

Exactly like with memory, containers will also see all the node’s CPUs, regardless of the CPU limits configured for the container. Setting a CPU limit to one core doesn’t magically only expose only one CPU core to the container. All the CPU limit does is constrain the amount of CPU time the container can use.  

A container with a one-core CPU limit running on a 64-core CPU will get 1/64th of the overall CPU time. And even though its limit is set to one core, the container’s processes will not run on only one core. At different points in time, its code may be executed on different cores.

Certain applications look up the number of CPUs on the system to decide how many worker threads they should run. Again, such an app will run fine on a development laptop, but when deployed on a node with a much bigger number of cores, it’s going to spin up too many threads. Also, each thread requires additional memory, causing the apps memory usage to skyrocket.  

__You may want to use the Downward API to pass the CPU limit to the container and use it instead of relying on the number of CPUs your app can see on the system__. You can also tap into the cgroups system directly to get the configured CPU limit by reading the following files:
- /sys/fs/cgroup/cpu/cpu.cfs_quota_us
- /sys/fs/cgroup/cpu/cpu.cfs_period_us

# Understanding pod qos classes
We’ve already mentioned that resource limits can be overcommitted and that a node can’t necessarily provide all its pods the amount of resources specified in their resource limits. Imagine having two pods, where pod A is using, let’s say, 90% of the node’s memory and then pod B suddenly requires more memory than what it had been using up to that point and the node can’t provide the required amount of memory. __Which container should be killed?__.  

Kubernetes does this by categorizing pods into three Quality of Service (QoS) classes:  

- BestEffort (the lowest priority). Containers running in these pods have had no resource guarantees whatsoever. In the worst case, they may get almost no CPU time at all and will be the first ones killed when memory needs to be freed for other pods. But because a BestEffort pod has no memory limits set, its containers may use as much memory as they want, if enough memory is available
- Burstable. In between BestEffort and Guaranteed is the Burstable QoS class. All other pods fall into this class. Burstable pods get the amount of resources they request, but are allowed to use additional resources (up to the limit) if needed
- Guaranteed (the highest). This class is given to pods whose containers’ requests are equal to the limits for all resources. Requests and __limits need to be set for both CPU and memory__. They __need to be set for each container__. They __need to be equal__


![QoS.png](.\Imagenes\QoS.png)

When the system is overcommitted, the QoS classes determine which container gets killed first so the freed resources can be given to higher priority pods. First in line to get killed are pods in the BestEffort class, followed by Burstable pods, and finally Guaranteed pods.  

## Understanding how QoS classes line up
Imagine having two single-container pods, where the first one has the BestEffort QoS class, and the second one’s is Burstable. When the node’s whole memory is already maxed out and one of the processes on the node tries to allocate more memory, __the system will need to kill__ one of the processes (perhaps even the process trying to allocate additional memory). The process running in the BestEffort pod will always be killed before the one in the Burstable pod. If a BestEffort pod’s process will also be killed before any Guaranteed pods’ processes are killed, the selection process needs to prefer one over the other. Each running process has an OutOfMemory (OOM) score. The system selects the process to kill by comparing OOM scores of all the running processes.  

OOM scores are calculated from two things: the percentage of the available memory the process is consuming and a fixed OOM score adjustment, which is based on the pod’s QoS class and the container’s requested memory. When two single-container pods exist, __both in the Burstable class, the system will kill the one using more of its requested memory than the other, percentage-wise__.  

# Setting default requests and limits for pods per namespace
Instead of having to do this for every container, you can also do it by creating a Limit-Range resource. It allows you to specify (for each namespace) not only the minimum and maximum limit you can set on a container for each resource, but also the default resource requests for containers that don’t specify requests explicitly.  

![LimitRange.png](.\Imagenes\LimitRange.png)

LimitRange resources are used by the __LimitRanger Admission Control plugin__. When a pod manifest is posted to the API server, the LimitRanger plugin validates the pod spec. If validation fails, the manifest is rejected immediately.  

The limits specified in a LimitRange resource apply to each individual pod/container or other kind of object created in the same namespace asº the LimitRange object. They don’t limit the total amount of resources available across all the pods in the namespace.  

```
apiVersion: v1
kind: LimitRange
metadata:
  name: example
spec:
  limits:
  - type: Pod                        1
    min:                             2
      cpu: 50m                       2
      memory: 5Mi                    2
    max:                             3
      cpu: 1                         3
      memory: 1Gi                    3
  - type: Container                  4
    defaultRequest:                  5
      cpu: 100m                      5
      memory: 10Mi                   5
    default:                         6
      cpu: 200m                      6
      memory: 100Mi                  6
    min:                             7
      cpu: 50m                       7
      memory: 5Mi                    7
    max:                             7
      cpu: 1                         7
      memory: 1Gi                    7
    maxLimitRequestRatio:            8
      cpu: 4                         8
      memory: 10                     8
  - type: PersistentVolumeClaim      9
    min:                             9
      storage: 1Gi                   9
    max:                             9
      storage: 10Gi                  9
```

- 1 Specifies the limits for a pod as a whole. They apply to the sum of all the pod’s containers’ requests and limits
- 2 Minimum CPU and memory all the pod’s containers can request in total
- 3 Maximum CPU and memory all the pod’s containers can request (and limit)
- 4 The container limits are specified below this line.
- 5 Default requests for CPU and memory that will be applied to containers that don’t specify them explicitly
- 6 Default limits for containers that don’t specify them
- 7 Minimum and maximum requests/limits that a container can have
- 8 Maximum ratio between the limit and request for each resource
- 9 A LimitRange can also set the minimum and maximum amount of storage a PVC can request.

At the container level, you can set not only the minimum and maximum, but also default resource requests (defaultRequest) and default limits (default). You can even set the maximum ratio of limits vs. requests. The previous listing sets the CPU maxLimitRequestRatio to 4, which means a container’s CPU limits will not be allowed to be more than four times greater than its CPU requests.   

Because the validation (and defaults) configured in a LimitRange object is performed by the API server when it receives a new pod or PVC manifest, if you modify the limits afterwards, existing pods and PVCs will not be revalidated.  

# Limiting the total resources available in a namespace
As you’ve seen, LimitRanges only apply to individual pods, but cluster admins also need a way to limit the total amount of resources available in a namespace. This is achieved by creating a ResourceQuota object.  

The ResourceQuota Admission Control plugin checks whether the pod being created would cause the configured ResourceQuota to be exceeded. If that’s the case, the pod’s creation is rejected. Because resource quotas are enforced at pod creation time, a ResourceQuota object only affects pods created after the Resource-Quota object is created.  

A ResourceQuota __limits the amount of computational resources the pods and the amount of storage PersistentVolumeClaims in a namespace can consume__. It __can also limit the number of pods, claims, and other API objects users are allowed to create inside the namespace__.  

```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cpu-and-mem
spec:
  hard:
    requests.cpu: 400m
    requests.memory: 200Mi
    limits.cpu: 600m
    limits.memory: 500Mi
```

This ResourceQuota sets the maximum amount of CPU pods in the namespace can request to 400 millicores. The maximum total CPU limits in the namespace are set to 600 millicores. For memory, the maximum total requests are set to 200 MiB, whereas the limits are set to 500 MiB.  

After you post the ResourceQuota object to the API server, you can use the kubectl describe command to see how much of the quota is already used up:  
```
kubectl describe quota

Name:           cpu-and-mem
Namespace:      default
Resource        Used   Hard
--------        ----   ----
limits.cpu      200m   600m
limits.memory   100Mi  500Mi
requests.cpu    100m   400m
requests.memory 10Mi   200Mi
```

One caveat when creating a ResourceQuota is that you will also want to create a Limit-Range object alongside it. __When a quota for a specific resource (CPU or memory) is configured (request or limit), pods need to have the request or limit (respectively) set for that same resource; otherwise the API server will not accept the pod__.  

## Specifying a quota for persistent storage

```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage
spec:
  hard:
    requests.storage: 500Gi                                      1
    ssd.storageclass.storage.k8s.io/requests.storage: 300Gi      2
    standard.storageclass.storage.k8s.io/requests.storage: 1Ti
```

In this example, the amount of storage all PersistentVolumeClaims in a namespace can request is limited to 500 GiB (by the requests.storage entry in the ResourceQuota object). PersistentVolumeClaims can request a dynamically provisioned PersistentVolume of a specific StorageClass. It is also possible to define storage quotas for each StorageClass individually. The previous example limits the total amount of claimable SSD storage (designated by the ssd StorageClass) to 300 GiB.  

A ResourceQuota can also be configured to limit the number of Pods, Replication-Controllers, Services, and other objects inside a single namespace. This allows the cluster admin to limit the number of objects users can create based on their payment plan, for example, and can also limit the number of public IPs or node ports Services can use.  

```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: objects
spec:
  hard:
    pods: 10                                                      1
    replicationcontrollers: 5                                     1
    secrets: 10                                                   1
    configmaps: 10                                                1
    persistentvolumeclaims: 4                                     1
    services: 5                                                   2
    services.loadbalancers: 1                                     2
    services.nodeports: 2                                         2
    ssd.storageclass.storage.k8s.io/persistentvolumeclaims: 2     3
```

# Monitoring pod resource usage
The Kubelet itself already contains an agent called cAdvisor, which performs the basic collection of resource consumption data for both individual containers running on the node and the node as a whole. Gathering those statistics centrally for the whole cluster requires you to run an additional component called Heapster.  

Heapster runs as a pod on one of the nodes and is exposed through a regular Kubernetes Service, making it accessible at a stable IP address. Collects the data from all cAdvisors in the cluster and exposes it in a single location. 

![Heapster.png](.\Imagenes\Heapster.png)

The pods (or the containers running therein) don’t know anything about cAdvisor, and cAdvisor doesn’t know anything about Heapster. It’s Heapster that connects to all the cAdvisors, and it’s the cAdvisors that collect the container and node usage data without having to talk to the processes running inside the pods’ containers.  

```
minikube addons enable heapster
```

After enabling Heapster, you’ll need to wait a few minutes for it to collect metrics before you can see resource usage statistics for your cluster, so be patient.  

The top command only shows current resource usages—it doesn’t show you how much CPU or memory your pods consumed throughout the last hour, yesterday, or a week ago, for example. In fact, both cAdvisor and Heapster only hold resource usage data for a short window of time. People usually use __InfluxDB__ for storing statistics data and __Grafana__ for visualizing and analyzing them.  

## Introducing InfluxDB and Grafana
InfluxDB is an open source time-series database ideal for storing application metrics and other monitoring data. Grafana, also open source, is an analytics and visualization suite with a nice-looking web console that allows you to visualize the data stored in InfluxDB and discover how your application’s resource usage behaves over time. Both InfluxDB and Grafana can run as pods.  

__When using Minikube__, you don’t even need to deploy them manually, because they’re deployed along with Heapster when you enable the Heapster add-on.  

When using Minikube, Grafana’s web console is exposed through a NodePort Service, so you can open it in your browser with the following command:

```
minikube service monitoring-grafana -n kube-system
```

![Grafana.png](.\Imagenes\Grafana.png)


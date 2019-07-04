Applications running in pods can be scaled out manually by increasing the replicas field in the ReplicationController, ReplicaSet, Deployment, or other scalable resource. Pods can also be scaled vertically by increasing their container’s resource requests and limits. Kubernetes can monitor your pods and scale them up automatically as soon as it detects an increase in the CPU usage or some other metric.  

# Horizontal pod autoscaling
Performed by the Horizontal controller, which is enabled and configured by creating a HorizontalPodAutoscaler (HPA) resource. The controller periodically checks pod metrics, calculates the number of replicas required to meet the target metric value configured in the HorizontalPodAutoscaler resource, and adjusts the replicas field on the target resource (Deployment, ReplicaSet, Replication-Controller, or StatefulSet).  

The autoscaling process can be split into three steps:
- Obtain metrics of all the pods managed by the scaled resource object.
- Calculate the number of pods required to bring the metrics to (or close to) the specified target value.
- Update the replicas field of the scaled resource.  

## Obtaining pod metrics
The Autoscaler doesn’t perform the gathering of the pod metrics itself. It gets the metrics from a different source. Node metrics are collected by an agent called __cAdvisor__, which __runs in the Kubelet on each node__, and then __aggregated by the cluster-wide component called Heapster__. The horizontal pod autoscaler controller gets the metrics of all the pods by querying Heapster through REST calls.  

![ScalingHeapster.png](.\Imagenes\ScalingHeapster.png)

__Heapster must be running in the cluster for autoscaling to work__.  

## Calculating the required number of pods
The Horizontal Autoescaler needs to find the number that will bring the average value of the metric across all those replicas as close to the configured target value as possible. When the Autoscaler is configured to consider only a single metric, calculating the required replica count is simple. The actual calculation is a bit more involved than this, because it also makes sure the Autoscaler doesn’t thrash around when the metric value is unstable and changes rapidly.  

When autoscaling is based on multiple pod metrics, (for example, both CPU usage and Queries-Per-Second [QPS]), the calculation isn’t that much more complicated. The Autoscaler calculates the replica count for each metric individually and then takes the highest value (for example, if four pods are required to achieve the target CPU usage, and three pods are required to achieve the target QPS, the Autoscaler will scale to four pods).  

![Escaling.png](.\Imagenes\Escaling.png)

The final step of an autoscaling operation is updating the desired replica count field on the scaled resource object. The Autoscaler controller modifies the replicas field of the scaled resource through the Scale sub-resource. It enables the Autoscaler to do its work without knowing any details of the resource it’s scaling. __This allows the Autoscaler to operate on any scalable resource, as long as the API server exposes the Scale sub-resource for it__:  
- Deployments
- ReplicaSets
- ReplicationControllers
- StatefulSets  

![AutoescalerE2E.png](.\Imagenes\AutoescalerE2E.png)

__It takes quite a while for the metrics data to be propagated and a rescaling action to be performed. It isn’t immediate__.  

## Scaling based on CPU utilization
Always set the target CPU usage well below 100% (and definitely never above 90%) to leave enough room for handling sudden load spikes.  

The process running inside a container is guaranteed the amount of CPU requested through the resource requests specified for the container. When someone says a pod is consuming 80% of the CPU, it’s not clear if they mean 80% of the node’s CPU, 80% of the pod’s guaranteed CPU (the resource request), or 80% of the hard limit configured for the pod through resource limits. __As far as the Autoscaler is concerned, only the pod’s guaranteed CPU amount (the CPU requests) is important when determining the CPU utilization of a pod__. Autoscaler compares the pod’s actual CPU consumption and its CPU requests, which means the pods you’re autoscaling need to have CPU requests set.  

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kubia
spec:
  replicas: 3                     
  template:
    metadata:
      name: kubia
      labels:
        app: kubia
    spec:
      containers:
      - image: luksa/kubia:v1     
        name: nodejs
        resources:              
          requests:            
            cpu: 100m           
```

After creating the Deployment, to enable horizontal autoscaling of its pods, you need to create a HorizontalPodAutoscaler (HPA) object and point it to the Deployment.  

```
kubectl autoscale deployment kubia --cpu-percent=30 --min=1 --max=5
```

Always make sure to __autoscale Deployments instead of the underlying ReplicaSets__. This way, you ensure the desired replica count is preserved across application updates.  

It takes a while for cAdvisor to get the CPU metrics and for Heapster to collect them before the Autoscaler can take action. During that time, if you display the HPA resource with kubectl get, the TARGETS column will show <unknown>:  

```
kubectl get hpa

NAME      REFERENCE          TARGETS           MINPODS   MAXPODS   REPLICAS
kubia     Deployment/kubia   <unknown> / 30%   1         5         0
```

Because you’re running three pods that are currently receiving no requests, which means their CPU usage should be close to zero, you should expect the Autoscaler to scale them down to a single pod:  

```
kubectl get deployment

NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubia     1         1         1            1           23m
```  

```
kubectl describe hpa

Name:                             kubia
Namespace:                        default
Labels:                           <none>
Annotations:                      <none>
CreationTimestamp:                Sat, 03 Jun 2017 12:59:57 +0200
Reference:                        Deployment/kubia
Metrics:                          ( current / target )
  resource cpu on pods
  (as a percentage of request):   0% (0) / 30%
Min replicas:                     1
Max replicas:                     5
Events:
From                        Reason              Message
----                        ------              ---
horizontal-pod-autoscaler   SuccessfulRescale   New size: 1; reason: All
                                                metrics below target
```

We are going to increase the load to see the HPA in action. We expose first the pods through a Service, so you can hit all of them through a single URL:  

```
kubectl expose deployment kubia --port=80 --target-port=8080
```

Run the following command in a separate terminal to keep an eye on what’s happening with the HorizontalPodAutoscaler and the Deployment:  

```
watch -n 1 kubectl get hpa,deployment

Every 1.0s: kubectl get hpa,deployment

NAME        REFERENCE          TARGETS    MINPODS   MAXPODS   REPLICAS  AGE
hpa/kubia   Deployment/kubia   0% / 30%   1         5         1         45m

NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/kubia   1         1         1            1           56m
```

Run the following command in another terminal:  

```
kubectl run -it --rm --restart=Never loadgenerator --image=busybox
```
This will run a pod which repeatedly hits the kubia Service. The --rm option causes the pod to be deleted afterward, and the --restart=Never option causes kubectl run to create an unmanaged pod directly instead of through a Deployment object, which you don’t need.  

As the load-generator pod runs, you’ll see it initially hitting the single pod. You can inspect autoscaler events with kubectl describe to see what the autoscaler has done.  

```
From    Reason              Message
----    ------              -------
h-p-a   SuccessfulRescale   New size: 1; reason: All metrics below target
h-p-a   SuccessfulRescale   New size: 4; reason: cpu resource utilization
                            (percentage of request) above target

```

Requests and its CPU usage spiked to 108%. Dividing 108 by 30 (the target CPU utilization percentage) gives 3.6, which the autoscaler then rounded up to 4.  

In my case, the CPU usage shot up to 108%, but in general, the initial CPU usage could spike even higher. Even if the initial average CPU utilization was higher (say 150%), requiring five replicas to achieve the 30% target, the autoscaler would still only scale up to four pods in the first step, because __it has a limit on how many replicas can be added in a single scale-up operation__. The autoscaler will at most double the number of replicas in a single operation, if more than two current replicas exist. If only one or two exist, it will scale up to a maximum of four replicas in a single step.  

It has a limit on how soon a subsequent autoscale operation can occur after the previous one. Currently, a scale-up will occur only if no rescaling event occurred in the last three minutes. A scale-down event is performed even less frequently—every five minutes.  

## Scaling based on memory consumption
Memory-based autoscaling is much more problematic than CPU-based autoscaling. The main reason is because after scaling up, the old pods would somehow need to be forced to release memory. This needs to be done by the app itself—it can’t be done by the system. All the system could do is kill and restart the app, hoping it would use less memory than before

## Scaling based on other and custom metrics
The definition of an HPA that scales based on CPU:  

```
...
spec:
  maxReplicas: 5
  metrics:
  - type: Resource                   1
    resource:
      name: cpu                      2
      targetAverageUtilization: 30   3
...
```
- 1 Defines the type of metric
- 2 The resource, whose utilization will be monitored
- 3 The target utilization of this resource

You have three types of metrics you can use in an HPA object:
- Resource
- Pods
- Object

### Resource
The Resource type makes the autoscaler base its autoscaling decisions on a resource metric, like the ones specified in a container’s resource requests.  

### Pods
The Pods type is used to refer to any other (including custom) metric related to the pod directly. An example of such a metric could be the already mentioned Queries-Per-Second (QPS) or the number of messages in a message broker’s queue.  

```
...
spec:
  metrics:
  - type: Pods                    
    resource:
      metricName: qps             
      targetAverageValue: 100     
...
```

### Object
The Object metric type is used when you want to make the autoscaler scale pods based on a metric that doesn’t pertain directly to those pods. For example, you may want to scale pods according to a metric of another cluster object, such as an Ingress object.  

Unlike in the previous case, where the autoscaler needed to obtain the metric for all targeted pods and then use the average of those values, when you use an Object metric type, __the autoscaler obtains a single metric from the single object__. In the HPA definition, you need to specify the target object and the target value.  

```
...
spec:
  metrics:
  - type: Object                           
    resource:
      metricName: latencyMillis            
      target:
        apiVersion: extensions/v1beta1     
        kind: Ingress                      
        name: frontend                     
      targetValue: 20                      
  scaleTargetRef:                          
    apiVersion: extensions/v1beta1         
    kind: Deployment                       
    name: kubia                            
...
```

In this example, the HPA is configured to use the latencyMillis metric of the frontend Ingress object.  

# Vertical pod autoscaling
Because a node usually has more resources than a single pod requests, it should almost always be possible to scale a pod vertically, right?. Because a pod’s resource requests are configured through fields in the pod manifest, vertically scaling a pod would be performed by changing those fields. But, vertical pod autoscaling is still not available yet.  

# Horizontal scaling of cluster nodes
A new node will be provisioned if, after a new pod is created, the Scheduler can’t schedule it to any of the existing nodes. 
# Introduction
There are two dimensions when it comes to analyze the security:
- Protect the access to the API Server. The API Server exposes a series of APIs that allows to manage the cluster, what is in etcd, create Pods, ...
- Protect what a container can do. The container is not a security construct. It simulates the isolation by using namespaces and resource groups, but that is not security. Under this topic we consider all things necessary to control what access to the Node a given Pod will have

# API Security
When a request is received by the API server, it goes through the list of authentication plugins. Several authentication plugins are available. They obtain the identity of the client using the following methods:  
- From the client certificate
- From an authentication token passed in an HTTP header
- Basic HTTP authentication
- Others

Kubernetes distinguishes between two kinds of clients connecting to the API server:  
- Actual humans (users)
- Pods

The pods use a mechanism called ``service accounts``, which are created and stored in the cluster as ``ServiceAccount resources``. In contrast, no resource represents user accounts.  

Both human users and ServiceAccounts can belong to one or more groups. Built-in groups have special meaning:  
- The __system:unauthenticated__ group is used for requests where none of the authentication plugins could authenticate the client.
- The __system:authenticated__ group is automatically assigned to a user who was authenticated successfully.
- The __system:serviceaccounts__ group encompasses all ServiceAccounts in the system.
- The __system:serviceaccounts:``<``namespace``>``__ includes all ServiceAccounts in a specific namespace.  

API server requires clients to authenticate themselves before they’re allowed to perform operations on the server. Pods can authenticate by sending a token in the Authentication header. The contents of the file/var/run/secrets/kubernetes.io/serviceaccount/token, which is mounted into each container’s filesystem through a secret volume, contain the token (the CA - required for validating the certificate on the https -, and the namespace - required in many api calls as input argument).  

Service-Account usernames are formatted like this:
```
system:serviceaccount:<namespace>:<service account name>
```
The API server passes this username to the configured authorization plugins, which determine whether the action the app is trying to perform is allowed to be performed by the ServiceAccount. We can see the ServiceAccounts created by:
```
kubectl get sa

NAME      SECRETS   AGE
default   1         1d
```
The Service Accounts (SA) can be shared by several Pods - in fact the default SA is shared by default by all __the Pods - within a namespace__:

![ServiceAccounts.png](Imagenes\ServiceAccounts.png)

By assigning different ServiceAccounts to pods, you can control which resources each pod has access to. The server uses the token to authenticate the client sending the request and then determines whether or not the related ServiceAccount is allowed to perform the requested operation. The API server obtains this information from the system-wide authorization plugin configured by the cluster administrator.  

We can __create a SA__:  
```
kubectl create serviceaccount foo
```
Lets see what was created:  
```
kubectl describe sa foo


Name:               foo
Namespace:          default
Labels:             <none>

Image pull secrets: <none>             
Mountable secrets:  foo-token-qzq7j    
Tokens:             foo-token-qzq7j    
```
With ``Image pull secrets`` we specify any credentials that we may need to fetch images from a private repo. With ``Mountable secrets`` we are specifying that this SA can only mount that specific secret - otherwise it will be able to mount any SA secret. Finally, ``Tokens`` tells us what is the name of the secret that represents this SA. If we run we can see the CA, namespace and token:  
```
kubectl describe secret foo-token-qzq7j

ca.crt:         1066 bytes
namespace:      7 bytes
token:          eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

```
By default, a pod can mount any Secret it wants. But the pod’s ServiceAccount can be configured to only allow the pod to mount Secrets that are listed as mountable Secrets on the Service-Account. To enable this feature, the ServiceAccount must contain the following __annotation__:  
 ```
 kubernetes.io/enforce-mountable-secrets="true"
 ```  
If the ServiceAccount is annotated with this annotation, any pods using it can mount only the ServiceAccount’s ``mountable Secrets`` — they can’t use/mount/see any other Secret.  

A ServiceAccount can also contain a list of ``image pull Secrets``. They are __Secrets that hold the credentials for pulling container images from a private image repository__. The values set in ``image pull Secrets`` don’t determine which image pull Secrets a pod can use, but which ones are added automatically to all pods using the Service-Account. Adding image pull Secrets to a ServiceAccount saves you from having to add them to each pod individually.  

The SA are specified in the Pod manifest:  
```
apiVersion: v1
kind: Pod
metadata:
  name: curl-custom-sa
spec:
  serviceAccountName: foo            
  containers:
  - name: main
    image: tutum/curl
    command: ["sleep", "9999999"]
  - name: ambassador
    image: luksa/kubectl-proxy:1.6.2
```
# RBAC
RBAC prevents unauthorized users from viewing or modifying the cluster state. The default Service-Account isn’t allowed to view cluster state, let alone modify it in any way, unless you grant it additional privileges.  


__Note__:In addition to RBAC, Kubernetes also includes other authorization plugins, such as the Attribute-based access control (ABAC) plugin, a Web-Hook plugin and custom plugin implementations. RBAC is the standard, though.  

__An authorization plugin such as RBAC, which runs inside the API server, determines whether a client is allowed to perform the requested verb on the requested resource or not__.  

The RBAC authorization rules are configured through four resources, which can be grouped into two groups:  
- Roles and ClusterRoles, which _specify which verbs can be performed on which resources_.
- RoleBindings and ClusterRoleBindings, which _bind the above roles to specific users, groups, or ServiceAccounts_.


![RBAC.png](Imagenes\RBAC.png)  

The distinction between a Role and a ClusterRole, or between a RoleBinding and a ClusterRoleBinding, is that the Role and RoleBinding are namespaced resources, whereas the ClusterRole and ClusterRoleBinding are cluster-level resources.  

![ClustervsNS.png](Imagenes\ClustervsNS.png)

# Demo
## Create a NS:  
```
kubectl create ns foo

kubectl create ns bar
```
## Create a deployment named test in the NS:  
```
kubectl run test --image=luksa/kubectl-proxy -n foo

kubectl run test --image=luksa/kubectl-proxy -n bar
```
We can see what we have created:  
```
kubectl get po -n foo

NAME                   READY     STATUS    RESTARTS   AGE
test-145485760-ttq36   1/1       Running   0          1m
```
We can open a bash:  
```
kubectl exec -it test-145485760-ttq36 -n foo sh
```
If we try to list the services:  
```
curl localhost:8001/api/v1/namespaces/foo/services

User "system:serviceaccount:foo:default" cannot list services in the namespace "foo".
```
We get this error because with RBAC enabled, the detault SA does not have the rights to list the resources, services in this example (The default permissions for a ServiceAccount don’t allow it to list or modify any resources).
## Role
A Role resource defines __what actions can be taken on which resources__ (or, as explained earlier, which types of HTTP requests can be performed on which RESTful resources). Here we have the definition of a role:  
```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: foo                     
  name: service-reader
rules:
- apiGroups: [""]                    
  verbs: ["get", "list"]             
  resources: ["services"]            
```
We are granting with this role the use of verbs ``get`` and ``list`` on the resource ``services``. The role is scoped at the namespace level.  

Services are resources in the core ``apiGroup``. Each resource type belongs to an API group, which you specify in the apiVersion field (along with the version) in the resource’s manifest. If you’re allowing access to resources belonging to different API groups, you use multiple rules.  

We can create this role now:  
```
kubectl create -f service-reader.yaml -n foo
```
## Bind the Role to a SystemAccount
A Role defines what actions can be performed, but it doesn’t specify who can perform them. For that we must bind the Role to a SystemAcount - user or group. Binding Roles to subjects is achieved by creating a ``RoleBinding resource``.
```
kubectl create rolebinding test --role=service-reader --serviceaccount=foo:default -n foo
```
We are binding the role ``service-reader`` to a serviceAccount named ``foo:default`` on the namespace ``foo``.
```
kubectl get rolebinding test -n foo -o yaml


apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: test
  namespace: foo
  ...
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role                           
  name: service-reader                 
subjects:
- kind: ServiceAccount                 
  name: default                        
  namespace: foo                       
```
A RoleBinding always references a single Role, but can bind the Role to multiple subjects. Now we can list the services:  
```
curl localhost:8001/api/v1/namespaces/foo/services

{
  "kind": "ServiceList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/foo/services",
    "resourceVersion": "24906"
  },
  "items": []                 1
}
```  
__Note:__ To bind the role to an user use the ``--user`` selector. To a group use the ``--group`` selector.  
## Cluster Role
Roles and RoleBindings are namespaced resources, meaning they reside in and apply to resources in a single namespace. In addition to these namespaced resources, two cluster-level RBAC resources also exist: ClusterRole and ClusterRoleBinding. __They’re not namespaced__. We can define a cluster role as follows:    
```
kubectl create clusterrole pv-reader --verb=get,list --resource=persistentvolumes
```
```
kubectl get clusterrole pv-reader -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:                                       
  name: pv-reader                               
  resourceVersion: "39932"                      
  selfLink: ...                                 
  uid: e9ac1099-30e2-11e7-955c-080027e6b159     
rules:
- apiGroups:                                    
  - ""                                          
  resources:                                    
  - persistentvolumes                           
  verbs:                                        
  - get                                         
  - list                                        
```
These roles will be binded to a user, serviceAccount or group:  
```
kubectl create clusterrolebinding pv-test --clusterrole=pv-reader --serviceaccount=foo:default
```

### Non URL resources
We can include in our role also non URL resources:  
```
kubectl get clusterrole system:discovery -o yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:discovery
  ...
rules:
- nonResourceURLs:      
  - /api                
  - /api/*              
  - /apis               
  - /apis/*             
  - /healthz            
  - /swaggerapi         
  - /swaggerapi/*       
  - /version            
  verbs:                
  - get                 
```
# Pod Security
In the previous chapter, we talked about securing the API server. Aren’t containers isolated from other containers and from the node they’re running on?.  

## Securing cluster nodes and the __network__
Containers in a pod usually run under separate Linux namespaces, which isolate their processes from processes running in other containers or in the node’s default namespaces.  
Each pod gets its own IP and port space, because it uses its own network namespace. Each pod has its own process tree, because it has its own PID namespace, it also uses its own IPC namespace, allowing only processes in the same pod to communicate with each other through the Inter-Process Communication mechanism (IPC).  
Certain pods (usually ___system pods___) __need to operate in the host’s default namespaces__, allowing them to see and manipulate node-level resources and devices. A pod may need to use the node’s network adapters instead of its own virtual network adapters. This can be achieved by setting the __hostNetwork__ property in the pod spec to true:

![NodeNetwork](Imagenes\NodeNetwork.png)
```
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-host-network
spec:
  hostNetwork: true                    
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
```

When the Kubernetes Control Plane components are deployed as pods, you’ll find that those pods use the hostNetwork option, effectively making them behave as if they weren’t running inside a pod.  

## Accessing the __node's port__ with the HostPort property
Another property in the same space is the HostPort property. This property maps a port in the Node to a port in the Pod, directly. It may look similar to the PortService, but it is not:
- The PortService frowards a port in the node to a service running in the node. The service will then loadbalance the request to a Pod, and to a Pod not necessarily running in the Node
- The binding of the Node port to the node happens only in those nodes where the Pods are running, not in all the nodes of the cluster

We can see these differences in the following diagram. Frist row shows the NodePort property in action; Second row shows the PortService:  

![HostProperty](Imagenes\NodePort.png)

It’s important to understand that __if a pod is using a specific host port, only one instance of the pod can be scheduled to each node__. The Scheduler takes this into account when scheduling pods, so it doesn’t schedule multiple pods to the same node.  
For example, suppose we have just three nodes and we want to scale to 4 Pods. One of the Pods will not be schedulled:  

![Schedulling](Imagenes\NodePortSchedulling.png)

Here we can see how the NodePort property is set:  

```
apiVersion: v1
kind: Pod
metadata:
  name: kubia-hostport
spec:
  containers:
  - image: luksa/kubia
    name: kubia
    ports:
    - containerPort: 8080     
      hostPort: 9000          
      protocol: TCP
```
We can reach the container at port 8080 of the Pod's IP, or at port 9000 of the Node's IP.  
The hostPort feature is primarily used for exposing system services, which are deployed to every node using DaemonSets.  
## Using the node’s __PID and IPC__ namespaces
Similar to the hostNetwork option are the hostPID and hostIPC pod spec properties. When you set them to true, the pod’s containers will use the node’s PID and IPC namespaces, allowing processes running in the containers to see all the other processes on the node or communicate with them through IPC, respectively.  
```
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-host-pid-and-ipc
spec:
  hostPID: true                      
  hostIPC: true                      
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
```
We have set the properties __hostPID__ and __hostIPC__. Here we are saying that the Pod will be able to use the PID namespace, and the IPC namespace.  

If now withing the Pod we list the processes, we are going to see all the processes running in the node (thanks to __hostPID__):  
```
kubectl exec pod-with-host-pid-and-ipc ps aux

PID   USER     TIME   COMMAND
    1 root       0:01 /usr/lib/systemd/systemd --switched-root --system ...
    2 root       0:00 [kthreadd]
    3 root       0:00 [ksoftirqd/0]
    5 root       0:00 [kworker/0:0H]
```
By setting the hostIPC property to true, processes in the pod’s containers can also communicate with all the other processes running on the node, __through Inter-Process Communication__.  
## __Security__ options

- __Specify the user__ (the user’s ID) under which the process in the container will run.
- __Prevent the container from running as root__ (the default user a container runs as is usually defined in the container image itself, so you may want to prevent containers from running as root).
- Run the container in __privileged mode__, giving it full access to the node’s kernel.
- Configure __fine-grained privileges__, by adding or dropping capabilities—in contrast to giving the container all possible permissions by running it in privileged mode.
- Set SELinux (__Security Enhanced Linux__) options to strongly lock down a container.
- __Prevent the process from writing to the container’s filesystem__.  

### Default configuration  

We create a Pod with the default configuration:  
```
kubectl run pod-with-defaults --image alpine --restart Never -- /bin/sleep 999999
```
We can see the Id under which the Pod is running:  
```
kubectl exec pod-with-defaults id
uid=0(root) gid=0(root) groups=0(root), 1(bin), 2(daemon), 3(sys), 4(adm), 6(disk), 10(wheel), 11(floppy), 20(dialout), 26(tape), 27(video)
```
The container is running under root.

### Specifying the user
You’ll need to set the pod’s securityContext.runAsUser property.  

```
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-user-guest
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 405 
```
User 405 corresponds to `Guest` in Alpine.  
```
kubectl exec pod-as-user-guest id

uid=405(guest) gid=100(users)
```

### Preventing a container from running as root
We don´t want to specify an specific user, but at the same time we do not want the Pod to run as root:  
```
apiVersion: v1
kind: Pod
metadata:
  name: pod-run-as-non-root
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:                   
      runAsNonRoot: true               
```

```
kubectl get po pod-run-as-non-root

NAME                 READY  STATUS
pod-run-as-non-root  0/1    container has runAsNonRoot and image will run as root
```

### Running pods in privileged mode
To get full access to the node’s kernel, the pod’s container runs in privileged mode. This is achieved by setting the privileged property in the container’s security-Context property to true.  
```
apiVersion: v1
kind: Pod
metadata:
  name: pod-privileged
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      privileged: true                 1
```
We can see the effect of this property by checking the devices to which we have access. First we check it in the container with default privileges:  
```
kubectl exec -it pod-with-defaults ls /dev

core             null             stderr           urandom
fd               ptmx             stdin            zero
full             pts              stdout
fuse             random           termination-log
mqueue           shm              tty

```
Now on the container that has been granted the privileged access:  
```
kubectl exec -it pod-privileged ls /dev

autofs              snd                 tty46
bsg                 sr0                 tty47
btrfs-control       stderr              tty48
core                stdin               tty49
cpu                 stdout              tty5
cpu_dma_latency     termination-log     tty50
fd                  tty                 tty51
full                tty0                tty52
fuse                tty1                tty53
hpet                tty10               tty54
hwrng               tty11               tty55
...                 ...                 ...
```

### Adding individual kernel capabilities to a container
Instead of making a container privileged and giving it unlimited permissions, a much safer method (from a security perspective) is to give it access only to the kernel features it really requires.  
For example, if we try to change the time of the OOSS:  
```
kubectl exec -it pod-with-defaults -- date +%T -s "12:00:00"

date: can't set date: Operation not permitted
```
We can now assign this specific privilege to the Pod:  
```
apiVersion: v1
kind: Pod
metadata:
  name: pod-add-settime-capability
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:                     
      capabilities:                      
        add:                             
        - SYS_TIME                       
```
Linux kernel capabilities are usually prefixed with CAP_. But when specifying them in a pod spec, you must leave out the prefix.  
```
kubectl exec -it pod-add-settime-capability -- date +%T -s "12:00:00"

12:00:00
```

### Dropping capabilities from a container
you can also drop capabilities that may otherwise be available to the container. For example, the default capabilities given to a container include the CAP_CHOWN capability, which allows processes to change the ownership of files in the filesystem.  
```
kubectl exec pod-with-defaults chown guest /tmp
```
```
kubectl exec pod-with-defaults -- ls -la / | grep tmp

drwxrwxrwt    2 guest    root             6 May 25 15:18 tmp
```
We can remove this capability using the property securityContext.capabilities.drop property:  

```
apiVersion: v1
kind: Pod
metadata:
  name: pod-drop-chown-capability
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      capabilities:
        drop:                   
        - CHOWN                 
```
Now: 
```
kubectl exec pod-drop-chown-capability chown guest /tmp

chown: /tmp: Operation not permitted
```

### Preventing processes from writing to the container’s filesystem

```
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-readonly-filesystem
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:                      
      readOnlyRootFilesystem: true        
    volumeMounts:                         
    - name: my-volume                     
      mountPath: /volume                  
      readOnly: false                     
  volumes:
  - name: my-volume
    emptyDir:
```
We are restricting the privileges of the Pod not to write on the File System with `readOnlyRootFilesystem: true`. At the same time we are mounting a folder and stating that the volumen can be written into with `readOnly: false`. The final result is that we can not write from the Pod into the filesystem except in the mounted folder.  
Here we do not have access:  
```
kubectl exec -it pod-with-readonly-filesystem touch /new-file
touch: /new-file: Read-only file system
```
But we do have access from the Pod to the mounted volume:  
```
kubectl exec -it pod-with-readonly-filesystem touch /volume/newfile

kubectl exec -it pod-with-readonly-filesystem -- ls -la /volume/newfile

-rw-r--r--    1 root     root       0 May  7 19:11 /mountedVolume/newfile
```
As shown in the example, when you make the container’s filesystem read-only, you’ll probably want to mount a volume in every directory the application writes to (for example, logs, on-disk caches, and so on).  

### Sharing volumes when containers run as different users
If we have two Pods and we want to share data between them, we can mount the same volume in the two Pods. That will work by default, because by default both Pods are running as root. Now, suppose that we are not running the Pods as root. Then things will not be assured. To assure that we have to use two properties:
- fsGroup. Owning group. the fsGroup security context property is used when the process creates files in a volume
- supplementalGroups. Defines a list of additional group IDs the user is associated with

Let use them with an example:   
```
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-shared-volume-fsgroup
spec:
  securityContext:                       1
    fsGroup: 555                         1
    supplementalGroups: [666, 777]       1
  
  containers:
  - name: first
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:                     2
      runAsUser: 1111                    2
    volumeMounts:                        3
    - name: shared-volume                3
      mountPath: /volume
      readOnly: false
  
  - name: second
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:                     4
      runAsUser: 2222                    4
    volumeMounts:                        3
    - name: shared-volume                3
      mountPath: /volume
      readOnly: false
  volumes:                               3
  - name: shared-volume                  3
    emptyDir:
```
- 1 The fsGroup and supplementalGroups are defined in the security context at the pod level  
- 2 The first container runs as user ID 1111  
- 3 Both containers use the same volume  
- 4 The second container runs as user ID 2222  

We can see the groups and owners of the files present in the volume. Lets see the id:  
```
kubectl exec -it pod-with-shared-volume-fsgroup -c first sh

id

uid=1111 gid=0(root) groups=555,666,777
´´´
The user in the first container is 1111, and belongs to the three groups 555, 666 and 777.  
Lets see the contents of the volume:  
´´´
ls -l / | grep volume

drwxrwsrwx    2 root     555              6 May 29 12:23 volume
```
Now we are creating a file:  
```
echo foo > /volume/foo

ls -l /volume

total 4
-rw-r--r--    1 1111     555              4 May 29 12:25 foo
```
See that in both cases the group owning the files is 555.  

## Restricting the use of security related features in Pods
We have seen how a person deploy a Pods that do a number of security sensible things:  
- Use Node IP
- Map a Node port to a Pod
- Run as root
- Write to the Node Filesystem
- Run the Pod with Privileges

Now we need to restrict who can submit a Pod that uses any of these characteristics. The cluster admin can restrict the use of the previously described security-related features by creating one or more __PodSecurityPolicy resources__.  

PodSecurityPolicy is a cluster-level (non-namespaced) resource, which defines what security-related features users can or can’t use in their pods. The job of upholding the policies configured in PodSecurityPolicy resources is performed by the PodSecurity-Policy admission control plugin running in the API server.  

When someone posts a pod resource to the API server, the PodSecurityPolicy admission control plugin validates the pod definition against the configured PodSecurityPolicies. __If the pod conforms to the cluster’s policies, it’s accepted and stored into etcd__; otherwise it’s rejected immediately.  
```
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
metadata:
  name: default
spec:
  hostIPC: false                 1
  hostPID: false                 1
  hostNetwork: false             1
  hostPorts:                     2
  - min: 10000                   2
    max: 11000                   2
  - min: 13000                   2
    max: 14000                   2
  privileged: false              3
  readOnlyRootFilesystem: true   4
  runAsUser:                     5
    rule: RunAsAny               5
  fsGroup:                       5
    rule: RunAsAny               5
  supplementalGroups:            5
    rule: RunAsAny               5
  seLinux:                       6
    rule: RunAsAny               6
  volumes:                       7
  - '*'                          7
```

- 1 Containers aren’t allowed to use the host’s IPC, PID, or network namespace.
- 2 They can only bind to host ports 10000 to 11000 (inclusive) or host ports 13000 to 14000.
- 3 Containers cannot run in privileged mode.
- 4 Containers are forced to run with a read-only root filesystem.
- 5 Containers can run as any user and any group.
- 6 They can also use any SELinux groups they want.
- 7 All volume types can be used in pods.  

```
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
spec:
  allowedCapabilities:            1
  - SYS_TIME                      1
  defaultAddCapabilities:         2
  - CHOWN                         2
  requiredDropCapabilities:       3
  - SYS_ADMIN                     3
  - SYS_MODULE                    3
  ...
```
- 1 Allow containers to add the SYS_TIME capability.
- 2 Automatically add the CHOWN capability to every container.
- 3 Require containers to drop the SYS_ADMIN and SYS_MODULE capabilities.  

The last thing a PodSecurityPolicy resource can do is define which volume types users can add to their pods. At the minimum, a PodSecurityPolicy should allow using at least the emptyDir, configMap, secret, downwardAPI, and the persistentVolumeClaim volumes.  

```
kind: PodSecurityPolicy
spec:
  volumes:
  - emptyDir
  - configMap
  - secret
  - downwardAPI
  - persistentVolumeClaim
```
## RBAC and Podsecuritypolicies
We mentioned that a PodSecurityPolicy is a cluster-level resource, which means it can’t be stored in and applied to a specific namespace. Does that mean it always applies across all namespaces?: No.  

Assigning different policies to different users is done through the RBAC mechanism. The idea is to create as many policies as you need and make them available to individual users or groups by creating ClusterRole resources and pointing them to the individual policies by name.  

By binding those ClusterRoles to specific users or groups with ClusterRoleBindings, when the PodSecurityPolicy Admission Control plugin needs to __decide whether to admit a pod definition or not, it will only consider the policies accessible to the user creating the pod__.  

### Example
Lets create first a __Podsecuritypolicy__:  
```
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
metadata:
  name: privileged          
spec:
  privileged: true          
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  volumes:
  - '*'
```
We can retrieve the list of security policies available:  
```
$ kubectl get psp

NAME         PRIV    CAPS   SELINUX    RUNASUSER   FSGROUP    ...
default      false   []     RunAsAny   RunAsAny    RunAsAny   ...
privileged   true    []     RunAsAny   RunAsAny    RunAsAny   ...
```
We are going to create a __clusterrole__ that has associated the Podsecuritypolicy we just created:  

```
kubectl create clusterrole psp-default --verb=use --resource=podsecuritypolicies --resource-name=default
```

We’re using the special verb use instead of get, list, watch, or similar. We'll create now the other clusterrole:  
```
kubectl create clusterrole psp-privileged --verb=use --resource=podsecuritypolicies --resource-name=privileged
```
We __bind the cluster role__ we want to assing to everybody:  
```
kubectl create clusterrolebinding psp-all-users --clusterrole=psp-default --group=system:authenticated
```
And the privileged cluster role to an specific user, bob:  
```
kubectl create clusterrolebinding psp-bob --clusterrole=psp-privileged --user=bob
```
Alice shouldn’t be able to create privileged pods, whereas Bob should. Let’s see if that’s true.  

### Creating additional users for kubectl
First, you’ll __create two new users__ in kubectl’s config with the following two commands-:
```
kubectl config set-credentials alice --username=alice --password=password

User "alice" set.
```
```
kubectl config set-credentials bob --username=bob --password=password

User "bob" set.
```
Because you’re setting username and password credentials, kubectl will use basic HTTP authentication for these two users.  
```
kubectl --user alice create -f pod-privileged.yaml
```
## Isolating the Pod Network
Up to now, we’ve explored many security-related configuration options that apply to individual pods and their containers, limiting which pods can talk to which pods. Now we are going to manage the relationship between Pods, who can communicate with whom.  
A NetworkPolicy applies to pods that match its label selector and specifies either which sources can access the matched pods or which destinations can be accessed from the matched pods. This is configured through ingress and egress rules, respectively.  
By default, pods in a given namespace can be accessed by anyone. First, you’ll need to change that. You’ll create a default-deny NetworkPolicy, which will prevent all clients from connecting to any pod in your namespace:  
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector:           
```
By specifying an empty pod selector we are matching all pods in the same namespace. When you create this NetworkPolicy in a certain namespace, no one can connect to any pod in that namespace.  
To let clients connect to the pods in the namespace, you must now explicitly say who can connect to the pods. Imagine having a PostgreSQL database pod running in namespace foo and a web-server pod that uses the database. Other pods are also in the namespace, and you don’t want to allow them to connect to the database.  
We create a NetworkPolicy resource in the same namespace as the database pod:  
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-netpolicy
spec:
  podSelector:                       1
    matchLabels:                     1
      app: database                  1
  ingress:                           2
  - from:                            2
    - podSelector:                   2
        matchLabels:                 2
          app: webserver             2
    ports:                           3
    - port: 5432                     3
```
- 1 This policy secures access to pods with app=database label.
- 2 With __ingress__ it allows incoming connections only from pods with the app=webserver label.
- 3 Connections to this port are allowed.  

Allows pods with the app=webserver label to connect to pods with the app=database label, and only on port 5432.  

![NetworkSecPolicy](Imagenes\NetworkSecPolicy.png)

Client pods usually connect to server pods through a Service instead of directly to the pod, but that doesn’t change anything. __The NetworkPolicy is enforced when connecting through a Service, as well__.  
### Isolating the network between Kubernetes namespaces
Suppose that multiple tenants are using the same Kubernetes cluster. Each tenant can use multiple namespaces, and each namespace has a label specifying the tenant it belongs to.  
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: shoppingcart-netpolicy
spec:
  podSelector:                       1
    matchLabels:                     1
      app: shopping-cart             1
  ingress:
  - from:
    - namespaceSelector:             2
        matchLabels:                 2
          tenant: manning            2
    ports:
    - port: 80
```
-	1 This policy applies to pods labeled as microservice= shopping-cart.
-	2 Only pods running in namespaces labeled as tenant=manning are allowed to access the microservice.  

Ensures only pods running in namespaces labeled as tenant: manning can access their Shopping Cart microservice.  

![NamespaceNetPol.png](Imagenes\NamespaceNetPol.png)

__Note__: In a multi-tenant Kubernetes cluster, __tenants usually can’t add labels (or annotations) to their namespaces__ themselves. If they could, they’d be able to circumvent the namespaceSelector-based ingress rules.  
### Isolating using CIDR notation
Instead of specifying a pod- or namespace selector to define who can access the pods targeted in the NetworkPolicy, you can also specify an IP block in CIDR notation.  
```
  ingress:
  - from:
    - ipBlock:                    
        cidr: 192.168.1.0/24      
```
This ingress rule only allows traffic from clients in the 192.168.1.0/24 IP block.  
### Limiting the outbound traffic of a set of pods
```
spec:
  podSelector:                
    matchLabels:              
      app: webserver          
  egress:                     
  - to:                       
    - podSelector:            
        matchLabels:          
          app: database       
```
Allows pods that have the app=webserver label to only access pods that have the app=database label and nothing else.
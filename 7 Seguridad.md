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
- The system:unauthenticated group is used for requests where none of the authentication plugins could authenticate the client.
- The system:authenticated group is automatically assigned to a user who was authenticated successfully.
- The system:serviceaccounts group encompasses all ServiceAccounts in the system.
- The system:serviceaccounts:<namespace> includes all ServiceAccounts in a specific namespace.  

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
The Service Accounts (SA) can be shared by several Pods - in fact the default SA is shared by default by all the Pods - __within a namespace__:

![ServiceAccounts.png](Imagenes\ServiceAccounts.png)

By assigning different ServiceAccounts to pods, you can control which resources each pod has access to. The server uses the token to authenticate the client sending the request and then determines whether or not the related ServiceAccount is allowed to perform the requested operation. The API server obtains this information from the system-wide authorization plugin configured by the cluster administrator.  

We can create a SA:  
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
With ``Image pull secrets`` we specify any credentials we may need to fetch images from a private repo. With ``Mountable secrets`` we are specifying that this SA can only mount that specific secret - otherwise it will be able to mount any SA secret. Finally, ``Tokens`` tells us what is the name of the secret that represents this SA. If we run:  
```
kubectl describe secret foo-token-qzq7j

ca.crt:         1066 bytes
namespace:      7 bytes
token:          eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

```
By default, a pod can mount any Secret it wants. But the pod’s ServiceAccount can be configured to only allow the pod to mount Secrets that are listed as mountable Secrets on the Service-Account. To enable this feature, the ServiceAccount must contain the following __annotation__: ``kubernetes.io/enforce-mountable-secrets="true"``.
If the ServiceAccount is annotated with this annotation, any pods using it can mount only the ServiceAccount’s ``mountable Secrets`` — they can’t use any other Secret.  

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
- Roles and ClusterRoles, which specify which verbs can be performed on which resources.
- RoleBindings and ClusterRoleBindings, which bind the above roles to specific users, groups, or ServiceAccounts.

![RBAC.png](Imagenes\RBAC.png)
The distinction between a Role and a ClusterRole, or between a RoleBinding and a ClusterRoleBinding, is that the Role and RoleBinding are namespaced resources, whereas the ClusterRole and ClusterRoleBinding are cluster-level resources.
![ClustervsNS.png](Imagenes\ClustervsNS.png)

# Demo
Create a NS:  
```
kubectl create ns foo
```
Create a deployment named test in the NS:  
```
kubectl run test --image=luksa/kubectl-proxy -n foo
```
Create another NS:  
```
kubectl create ns bar
```
Create the deployment named test in the new NS:  
```
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
A Role resource defines what actions can be taken on which resources (or, as explained earlier, which types of HTTP requests can be performed on which RESTful resources). Here we have the definition of a role:  
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
We are granting with this role the use of verbs ``get`` and ``list`` on the resource ``services``. The role is scoped at the namespace level. Services are resources in the core apiGroup. Each resource type belongs to an API group, which you specify in the apiVersion field (along with the version) in the resource’s manifest. If you’re allowing access to resources belonging to different API groups, you use multiple rules.  

We can create this role now:  
```
kubectl create -f service-reader.yaml -n foo
```

# Extending Kubernetes
Instead of dealing with Deployments, Services, ConfigMaps, and the like, you’ll __create and manage objects that represent whole applications or software services__. A `custom controller` will observe those high-level objects and create low-level objects based on them. All you need to do is post a `CustomResourceDefinition object (CRD)` to the Kubernetes API server. The CustomResourceDefinition object is the description of the custom resource type.  

Creating a CRD so that users can create objects of the new type isn’t a useful feature if those objects don’t make something tangible happen in the cluster.

## Example
You want to allow users of your Kubernetes cluster to run static websites as easily as possible. For users to create objects of type Website that contain nothing more than the website’s name and the source from which the website’s files (HTML, CSS, PNG, and others) should be obtained.  

![CustomResource.png](./Imagenes/CustomResource.png)

```
kind: Website                                                   1
metadata:
  name: kubia                                                   2
spec:
  gitRepo: https://github.com/luksa/kubia-website-example.git   3
```
- 1 A custom object kind
- 2 The name of the website (used for naming the resulting Service and Pod)
- 3 The Git repository holding the website’s files

If you try posting this resource to Kubernetes, you’ll receive an error because __Kubernetes doesn’t know what a Website object is yet__. You need to make Kubernetes recognize them. We will create a CustomResourceDefinition, or CRD for that:  

```
apiVersion: apiextensions.k8s.io/v1beta1       
kind: CustomResourceDefinition                 
metadata:
  name: websites.extensions.example.com        
spec:
  scope: Namespaced                            
  group: extensions.example.com                
  version: v1                                  
  names:                                       
    kind: Website                              
    singular: website                          
    plural: websites                           
```

This CRD will be in charge of letting you to create any number of instances of the custom Website resource. We will issue the creation of the CRD with the following command:  

```
kubectl create -f website-crd-definition.yaml

customresourcedefinition "websites.extensions.example.com" created
```

When you create a resource handled by this CRD we will have to refer to the group in the `apiVersion` of the resource definition:  

```
apiVersion: extensions.example.com/v1         
kind: Website                                 
metadata:
  name: kubia                                 
spec:
  gitRepo: https://github.com/luksa/kubia-website-example.git
```

The kind of your resource is Website, and the apiVersion is composed of the API group and the version number you defined in the CustomResourceDefinition. We can now create the resource:  

```
kubectl create -f kubia-website.yaml

website "kubia" created
```

We can ask the kubectl for these resources:  

```
kubectl get websites

NAME      KIND
kubia     Website.v1.extensions.example.com
```

We can delete the resources:  

```
kubectl delete website kubia

website "kubia" deleted
```

There is a missing ingredient, the __Controller__. To make your Website objects run a web server pod exposed through a Service, you’ll need to build and deploy a Website controller. In our example the Controller will make sure the Pod is managed and survives node failures by creating a Deployment resource.  

![ControllerExample.png](./Imagenes/ControllerExample.png)

I’ve written a simple initial version of the controller, which works well enough to show CRDs and the controller in action, but it’s far from being production-ready, because it’s overly simplified. The container image is available at docker.io/luksa/ website-controller:latest, and the source code is at https://github.com/luksa/k8s-website-controller (the repo has been cloned).  

Immediately upon startup, __the controller starts to watch Website objects__ by requesting the URL `http://localhost:8001/apis/extensions.example.com/v1/websites?watch=true`.  

```
func main() {
	log.Println("website-controller started.")
	for {
		resp, err := http.Get("http://localhost:8001/apis/extensions.example.com/v1/websites?watch=true")
```

The controller isn’t connecting to the API server directly, but is instead connecting to the kubectl proxy process, which runs in a sidecar container in the same pod and acts as the ambassador to the API server. the API server will send watch events for every change to any Website object.  

The API server sends the ADDED watch event every time a new Website object is created. When the controller receives such an event, it extracts the Website’s name and the URL of the Git repository from the Website object it received in the watch event and creates a Deployment and a Service object by posting their JSON manifests to the API server.  

```
for {
...
    if event.Type == "ADDED" {
        createWebsite(event.Object)
    } else if event.Type == "DELETED" {
        deleteWebsite(event.Object)
    }
}
```

```
func createWebsite(website v1.Website) {
	createResource(website, "api/v1", "services", "service-template.json")
	createResource(website, "apis/extensions/v1beta1", "deployments", "deployment-template.json")
}

func deleteWebsite(website v1.Website) {
	deleteResource(website, "api/v1", "services", getName(website));
	deleteResource(website, "apis/extensions/v1beta1", "deployments", getName(website));
}
```

We refer to two resources, a `service` and a `deployment`, defined in two templates (you can see the json`s for the two resources).  

![Controller.png](./Imagenes/Controller.png)

The Deployment resource contains a template for a pod with two containers. The local directory is shared with the nginx container through an emptyDir volume. The Service is a NodePort Service, which exposes your web server pod through a random port on each node. When a pod is created by the Deployment object, clients can access the website through the node port.  

The API server also sends a DELETED watch event when a Website resource instance is deleted. Upon receiving the event, the controller deletes the Deployment and the Service resources it created earlier.  

__To run the controller in Kubernetes, you can deploy it through a Deployment resource__. The following listing shows an example of such a Deployment.  

```
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: website-controller
spec:
  replicas: 1                                        
  template:
    metadata:
      name: website-controller
      labels:
        app: website-controller
    spec:
      serviceAccountName: website-controller         
      containers:                                    
      - name: main                                   
        image: luksa/website-controller              
      - name: proxy                                  
        image: luksa/kubectl-proxy:1.6.2             
```

As you can see, the Deployment deploys a single replica of a two-container pod. __One container runs your controller__, whereas the other one is the __ambassador container used for simpler communication with the API server__. If __Role Based Access Control (RBAC) is enabled__ in your cluster, __Kubernetes will not allow the controller to watch Website resources or create Deployments or Services__. To allow it to do that, you’ll __need to bind the website-controller ServiceAccount__ to the __cluster-admin ClusterRole__, by creating a ClusterRoleBinding:  

```
kubectl create clusterrolebinding website-controller --clusterrole=cluster-admin --serviceaccount=default:website-controller
```

Once you have the ServiceAccount and ClusterRoleBinding in place, you can deploy the controller’s Deployment. With the controller now running create the kubia Website resource again:  

```
kubectl create -f kubia-website.yaml

website "kubia" created
```

We can see the events at the controller:  

```
kubectl logs website-controller-2429717411-q43zs -c main

2017/02/26 16:54:41 website-controller started.
2017/02/26 16:54:47 Received watch event: ADDED: kubia: https://github.c...
2017/02/26 16:54:47 Creating services with name kubia-website in namespa...
2017/02/26 16:54:47 Response status: 201 Created
2017/02/26 16:54:47 Creating deployments with name kubia-website in name...
2017/02/26 16:54:47 Response status: 201 Created
```

The logs show that the controller received the `ADDED event` and that it created a Service and a Deployment for the kubia-website Website. Let’s verify that the Deployment, Service and the resulting Pod were created:  

```
kubectl get deploy,svc,po

NAME                        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE  AGE
deploy/kubia-website        1         1         1            1          4s
deploy/website-controller   1         1         1            1          5m

NAME                CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
svc/kubernetes      10.96.0.1      <none>        443/TCP        38d
svc/kubia-website   10.101.48.23   <nodes>       80:32589/TCP   4s

NAME                                     READY     STATUS    RESTARTS   AGE
po/kubia-website-1029415133-rs715        2/2       Running   0          4s
po/website-controller-1571685839-qzmg6   2/2       Running   1          5m
```  

## Validating custom objects
You may have noticed that you didn’t specify any kind of validation schema in the Website CustomResourceDefinition. __Users can include any field they want in the YAML of their Website object__. The API server doesn’t validate the contents of the YAML (except the usual fields like apiVersion, kind, and metadata).  

Is it possible to add validation to the controller and prevent invalid objects from being accepted by the API server? It isn’t, because the API server first stores the object, then returns a success response to the client (kubectl), and only then notifies all the watchers (the controller is one of them). __All the controller can really do is validate the object when it receives it in a watch event, and if the object is invalid, write the error message to the Website object (by updating the object through a new request to the API server)__. __The user wouldn’t be notified of the error automatically__. They’d have to notice the error message by querying the API server for the Website object. Unless the user does this, they have no way of knowing whether the object is valid or not.  

It isn’t ideal. You’d want the API server to validate the object and reject invalid objects immediately. Validation of custom objects was introduced in Kubernetes version 1.8 as an alpha feature. To have the API server validate your custom objects, you need to enable the CustomResourceValidation feature gate in the API server and specify a JSON schema in the CRD.  

## Providing a custom API server for your custom objects
A better way of adding support for custom objects in Kubernetes is to implement your own API server and have the clients talk directly to it. You can integrate your custom API server with the main Kubernetes API server, through API server aggregation. Clients can connect to the aggregated API and have their requests transparently forwarded to the appropriate API server. The client wouldn’t even be aware that multiple API servers handle different objects behind the scenes.  

![CustomServer.png](./Imagenes/CustomServer.png)

You’d no longer need to create a CRD to represent those objects, because you’d implement the Website object type into the custom API server directly. Generally, each API server is responsible for storing their own resources.  

### Registering a custom API server
To add a custom API server to your cluster, you’d deploy it as a pod and expose it through a Service.  

```
apiVersion: apiregistration.k8s.io/v1beta1   1
kind: APIService                             1
metadata:
  name: v1alpha1.extensions.example.com
spec:
  group: extensions.example.com              2
  version: v1alpha1                          3
  priority: 150
  service:                                   4
    name: website-api                        4
    namespace: default                       4
```  

- 1 This is an APIService resource.
- 2 The API group this API server is responsible for
- 3 The supported API version
- 4 The Service the custom API server is exposed through  

After creating the APIService resource from the previous listing, __client requests sent to the main API server that contain any resource from the extensions.example.com API group and version v1alpha1 would be forwarded to the custom API server pod(s) exposed through the website-api Service__. 

# Extending kubernetes with the kubernetes service catalog
One of the first additional API servers that will be added to Kubernetes through API server aggregation is the Service Catalog API server. Service Catalog is a hot topic in the Kubernetes community. Currently, for a pod to consume a service someone needs to deploy the pods providing the service, a Service resource, and possibly a Secret so the client pod can use it to authenticate with the service.  

“Hey, I need a PostgreSQL database. Please provision one and tell me where and how I can connect to it.” This will soon be possible through the Kubernetes Service Catalog.  

The Service Catalog is a catalog of services. Users can browse through the catalog and provision instances of the services listed in the catalog by themselves without having to deal with Pods, Services, ConfigMaps, and other resources required. The Service Catalog introduces the following four generic API resources:  
- A ClusterServiceBroker, which describes an (external) system that can provision services
- A ClusterServiceClass, which describes a type of service that can be provisioned
- A ServiceInstance, which is one instance of a service that has been provisioned
- A ServiceBinding, which represents a binding between a set of clients (pods) and a ServiceInstance

![ServiceCatalogue.png](./Imagenes/ServiceCatalogue.png)  

In a nutshell, a cluster admin creates a ClusterServiceBroker resource for each service broker whose services they’d like to make available in the cluster.  

__Kubernetes then asks the broker for a list of services that it can provide and creates a ClusterServiceClass resource for each of them__.  

When a user requires a service to be provisioned, they __create an ServiceInstance resource__ and then a __ServiceBinding to bind that Service-Instance to their pods__. Those pods are then injected with a Secret that holds all the necessary credentials and other data required to connect to the provisioned ServiceInstance.

# Introducing the Service Catalog API server and Controller Manager
Similar to core Kubernetes, the Service Catalog is a distributed system composed of three components:  
- Service Catalog API Server
- etcd as the storage
- Controller Manager, where all the controllers run  

The four Service Catalog–related resources we introduced earlier are created by posting YAML/JSON manifests to the API server. It then stores them into its own etcd instance or uses.  

The controllers running in the Controller Manager are the ones doing something with those resources. They obviously talk to the Service Catalog API server. Those controllers don’t provision the requested services themselves. They leave that up to external service brokers, which are registered by creating ServiceBroker resources in the Service Catalog API.  

A cluster administrator can register one or more external ServiceBrokers in the Service Catalog. Every broker must implement the OpenServiceBroker API.  

The Service Catalog talks to the broker through that API. The API is relatively simple. It’s a REST API providing the following operations:  

- Retrieving the list of services with GET /v2/catalog
- Provisioning a service instance (PUT /v2/service_instances/:id)
- Updating a service instance (PATCH /v2/service_instances/:id)
- Binding a service instance (PUT /v2/service_instances/:id/service_bindings/:binding_id)
- Unbinding an instance (DELETE /v2/service_instances/:id/service_bindings/:binding_id)
- Deprovisioning a service instance (DELETE /v2/service_instances/:id)


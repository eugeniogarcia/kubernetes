# KNative Serving
Knative introduce varios recursos:  
- __Configuration__. Se encarga de definir el pod. Cuando se crea una configuracion, y cada vez que la modificamos, se crea un recurso, inmutable, llamado Revision
- __Revision__. Representa cada una de las versiones que hemos tenido del Pod. No creamos revisiones directamente, se crean indirectamente cuando modificamos una `Configuration` o un `Service`
- __Route__. Define como se gestiona el trafico a la aplicacion. Podemos definir A/B testing, blue/green deployments,...  
- __Service__. Es un recurso que esta jerarquicamente por encima de Configuration y de Route. Tipicamente no crearemos/modificaremos Configurations, sino Services. Cuando creamos un Service con un nombre xxxx, se crea una `Configuration` con el nombre xxxx, y una `Route` asociada con el nombre xxxx. No hay que confundir con el recurso Service de Kubernetes. Este objeto esta definido en la api de knative-serving. Tiene un alias diferente, `ksvc`

## Configuracion
```
kubectl get configuration
kubectl get configuration knative-helloworld -o yaml 
```
```
apiVersion: serving.knative.dev/v1alpha1
kind: Configuration
metadata:
  name: knative-helloworld
  namespace: default
spec:
  template:
    spec:
      container:
        image: docker.io/gswk/knative-helloworld:latest
        env:
          - name: MESSAGE
            value: "Knative!"
```
Si hacemos:  
```
kubectl get configuration knative-helloworld -o yaml
```
Veremos:  
```
apiVersion: serving.knative.dev/v1beta1
kind: Configuration
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"serving.knative.dev/v1alpha1","kind":"Configuration","metadata":{"annotations":{},"name":"knative-helloworld","namespace":"default"},"spec":{"template":{"spec":{"container":{"env":[{"name":"MESSAGE","value":"Knative!"}],"image":"docker.io/gswk/knative-helloworld:latest"}}}}}
  creationTimestamp: "2019-07-17T00:24:38Z"
  generation: 1
  labels:
    serving.knative.dev/route: knative-helloworld
  name: knative-helloworld
  namespace: default
  resourceVersion: "14150"
  selfLink: /apis/serving.knative.dev/v1beta1/namespaces/default/configurations/knative-helloworld
  uid: 77be0662-a9da-4ccf-a226-ce3999e74edc
spec:
  template:
    metadata:
      creationTimestamp: null
    spec:
      containers:
      - env:
        - name: MESSAGE
          value: Knative!
        image: docker.io/gswk/knative-helloworld:latest
        name: user-container
        resources: {}
      timeoutSeconds: 300
status:
  conditions:
  - lastTransitionTime: "2019-07-17T00:24:45Z"
    status: "True"
    type: Ready
  latestCreatedRevisionName: knative-helloworld-xlzfl
  latestReadyRevisionName: knative-helloworld-xlzfl
  observedGeneration: 1
```
Podemos ver `latestCreatedRevisionName` y `latestReadyRevisionName`, cual es el numero de la releases que han habido `observedGeneration` ...   

## Revisiones
```
kubectl get revisions
```
## Rutas
```
kubectl get routes
```
```
apiVersion: serving.knative.dev/v1alpha1
kind: Route
metadata:
  name: knative-helloworld
  namespace: default
spec:
  traffic:
  - configurationName: knative-helloworld
    percent: 100
```
En el caso anterior estamos creando una ruta con el nombre `knative-helloworld`, en el namespace `default`. Esto significa que la ruta seria `knative-helloworld.default.example.com`. `example.com` es el dominio por defecto creado en knative. El DNS, `coreDNS` registra este dominio. Veremos mas adelante como cambiarlo.  

Tambien podemos observar como esta ruta apunta a la ultima version de la COnfiguration `knative-helloworld`, a la que estaria derivando el 100% del trafico.  

Podemos probar el Servicio haciendo un curl desde el exterior del cluster. EN este caso tengo un minikube sin un balanceador de carga. El `Istio-Ingress gateway` esta implementado como un `NodePort service` en el puerto 31659. Si la IP del nodo es 192.168.1.139:  

```
curl -H "Host: knative-helloworld.default.example.com" http://192.168.1.139:31659 -v
```

## Servicios
Notese el alias que usamos:  
```
kubectl get ksvc
```

Aqui creamos un servicio basico llamado `knative-holamundo`. Cuando creemos el servicio se creara una `Configuration` llamada `knative-holamundo`, y una `Route` llamada `knative-holamundo`. La configuration se crea con la spec indicada. Como no hemos dicho nada al respecto de como crear la ruta, se creara una por defecto "igual" a la que indicamos en la seccion anterior:  

```
apiVersion: serving.knative.dev/v1alpha1
kind: Service
metadata:
  name: knative-holamundo
  namespace: default
spec:
  runLatest:
    configuration:
      revisionTemplate:
        spec:
          container:
            image: docker.io/gswk/knative-helloworld:latest
```
# Escalado
A key principle of serverless is scaling up to meet demand and down to
save resources. Knative uses two key components to achieve this
functionality. It implements `Autoscaler` and `Activator` as Pods on the
cluster. 

```
kubectl get po -n knative-serving
```

The Autoscaler gathers information about the number of concurrent
requests to a Revision. To do so, it runs a container called the queueproxy
inside the Revision’s Pod that also runs the user-provided
image.  
```
...
Containers:
user-container:
Container ID: docker://f02dc...
Image: index.docker.io/gswk/knative-helloworld...
...
queue-proxy:
Container ID: docker://1afcb...
Image: gcr.io/knative-releases/github.com/knative...
...
```  

´´´
kubectl logs knative-helloworld-qfxxd-deployment-5b6449cf78-znnqg -c queue-proxy
´´´

It then sends this data to the Autoscaler every one second. The Autoscaler evaluates these metrics every two seconds. By default, the Autoscaler tries to maintain an average of 100 requests per Pod per second. __The Autoscaler can also be configured to leverage the Kubernetes Horizontal Pod Autoscaler (HPA) instead. This will autoscale based on CPU usage but does not support scaling to zero__.  

For example, say a Revision is receiving 350 requests per second and each request takes about .5 seconds. Using the default setting of 100 requests per Pod, the Revision will receive 2 Pods:  

350 * .5 = 175
175 / 100 = 1.75
ceil(1.75) = 2 pods  

The Autoscaler is also responsible for scaling down to zero.

When a Revision stops receiving traffic, the Autoscaler moves it to the Reserve state. For this to happen the average concurrency per Pod __must remain at 0.0
for 30 seconds__. In the Reserve state, a Revision’s underlying Deployment scales to zero and all its traffic gets routed to the Activator. The Activator is a
shared component that catches all traffic for Reserve Revisions.  

### How Autoscaler Scales
It maintains both a 60-second window and a 6-second window. The Autoscaler then uses this data to operate in two different modes: Stable Mode and Panic Mode. In
Stable Mode, it uses the 60-second window average to determine how it should scale the Deployment to meet the desired concurrency. If the 6-second average concurrency reaches twice the desired target, the Autoscaler transitions into Panic Mode and uses the 6-second window instead.  

These properties are configurable in a ConfigMap attached to the Autoscaler

# KNative Build
The example used in this section can be found in the folder `knative-build-demo`.  

## Service Accounts
How do we reach out to services that require authentication at build-time? How do we pull code from a private Git repository or push container images to Docker Hub?. For this, we can leverage a combination of two Kubernetes-native components: 
Secrets and Service Accounts.  

```
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-account
  annotations:
    build.knative.dev/docker-0: https://index.docker.io/v1/
type: kubernetes.io/basic-auth
data:
  # 'echo -n "egsmartin" | base64'
  username: ZWdzbWFydGlu
  password: VmVyYTE1MTE=
```

Both the username and password are base64 encoded when passed to Kubernetes. We’re using basic-auth to authenticate against Docker Hub. Knative also ships with ssh-auth out of the box, allowing us to authenticate using an SSH private key if we would like to pull code from a private Git repository, for example.  

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-bot
secrets:
- name: dockerhub-account
```  

## Build resource
Now we can procedd to build the software and create an image. We can use the `build` resource:  

```
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: knative-build-demo
spec:
  serviceAccountName: build-bot
  source:
    git:
      url: https://github.com/gswk/knative-build-demo.git
      revision: master
  template:
    name: kaniko
    arguments:
    - name: IMAGE
      value: docker.io/egsmartin/knative-helloworld:latest
```

This will use the `kaniko` template to create an image using the code in `https://github.com/gswk/knative-build-demo.git`, and then push the resulting image to `docker.io/egsmartin/knative-helloworld:latest`.  

The build is performed by a job. We can see the progress of the build in this way:  

```
kubectl -n default logs knative-build-demo-pod-6a362d -c build-step-build-and-push
```

The kaniko template need a `DOCKERFILE` that has to be present in the git repository with the source code.  

The kaniko template is as follows:  
```
apiVersion: build.knative.dev/v1alpha1
kind: BuildTemplate
metadata:
  name: kaniko
spec:
  parameters:
  - name: IMAGE
    description: The name of the image to push
  - name: DOCKERFILE
    description: Path to the Dockerfile to build.
    default: /workspace/Dockerfile
  steps:
  - name: build-and-push
    image: gcr.io/kaniko-project/executor
    args:
    - --dockerfile=${DOCKERFILE}
    - --destination=${IMAGE}
```

The kaniko template has to be installed in the cluster first:  
```
kubectl apply -f https://raw.githubusercontent.com/knative/build-templates/master/kaniko/kaniko.yaml
```

Once the build pod does its job, in https://cloud.docker.com/repository/docker/egsmartin/knative-helloworld we would see the image published.  

# KNative Eventing
The loosely coupled nature of serverless fits an event-driven architecture as well. Rather than having our applications and functions worry about the logic of watching for these events, instead we can express interest in certain events and let Knative handle letting us know when they occur.  

Knative provides a layer of abstraction that makes it easy to consume events. Instead of writing code specific to your message broker of choice, Knative simply delivers an “event.” Your application doesn’t have to care where it came from or how it got there, just simply that it happened.  

## Sources
Sources are the source of the events. The Knative teams have developed a number of Sources that are provided right out of the box:  
- GCP PubSub. Subscribe to a topic in Google’s PubSub Service and listen for
messages
- Kubernetes Events. Events happening in the Kubernetes cluster.
- GitHub. Events in a GitHub repository, such as pull requests, pushes, and creation of releases.
- Container Source. Knative has a further abstraction, a Container Source. This allows you to easily create your own Event Source, packaged as a container.  

We are going to create an standard service that will become later on the sink of an stream flow. The service:  

```
apiVersion: serving.knative.dev/v1alpha1
kind: Service
metadata:
  name: knative-eventing-demo
spec:
  runLatest:
    configuration:
      revisionTemplate:
        spec:
          container:
            image: docker.io/gswk/knative-eventing-demo:latest
```

We can check that the service is operational:  

```
curl http://192.168.1.139:31659 -H "Host: knative-eventing-demo.default.example.com" -v -XPOST -d "Hola, amigos"
```

We can now set up the source of the stream. For the Kubernetes Event Source, we’ll need to create a Service Account that has permission to read the events happening inside of our Kubernetes cluster:  

First we create a service account:  
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: events-sa
  namespace: default
```

Now we create a role that has rights to consume Kubernetes events:  

```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  creationTimestamp: null
  name: event-watcher
rules:
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - get
  - list
  - watch
```  

Finally we bing the role to the account:  
```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  creationTimestamp: null
  name: k8s-ra-event-watcher
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: event-watcher
subjects:
- kind: ServiceAccount
  name: events-sa
  namespace: default
```

And finally we are going to create a __Source__:  

```
apiVersion: sources.eventing.knative.dev/v1alpha1
kind: ApiServerSource
metadata:
  name: testevents
  namespace: default
spec:
  serviceAccountName: events-sa
  mode: Resource
  resources:
    - apiVersion: v1
      kind: Event
  sink:
    apiVersion: eventing.knative.dev/v1alpha1
    kind: Channel
    name: knative-eventing-demo-channel
```

We are saying that this source is to be connected to a sink, a `Channel`.  

## Channels
While you can send events straight to a Service, this means it’s up to you to handle retry logic and queuing. And what happens when an event is sent to your Service and it happens to be down? What if you want to send the same events to multiple Services?.  

Channels handle buffering and persistence. Channels are an abstraction between our code and the underlying messaging solution. something like Kafka and RabbitMQ, but in neither case are we writing code specific to either.

```
apiVersion: eventing.knative.dev/v1alpha1
kind: Channel
metadata:
  name: knative-eventing-demo-channel
spec:
  provisioner:
    apiVersion: eventing.knative.dev/v1alpha1
    kind: ClusterChannelProvisioner
    name: in-memory
```
In this case we have created an inmemory-channel. As mentioned before, a big goal of eventing in Knative is that it’s completely abstracted away from the underlying infrastructure, and this means making the messaging service backing our Channels pluggable. This is done by implementations of the ClusterChannelProvisioner, a pattern for defining how Knative should communicate with our messaging services.  

- in-memory-channel. Handled completely in-memory inside of our Kubernetes cluster
and does not rely on a separate running service to deliver events. Great for development but is not recommended to be used in production
- GCP PubSub
- Kafka

## Subscriptions
We have our Event Source sending events to a Channel, and a Service ready to go to start processing them. Subscriptions are the glue between Channels and Services.  

```
apiVersion: eventing.knative.dev/v1alpha1
kind: Subscription
metadata:
  name: knative-eventing-demo-subscription
spec:
  channel:
    apiVersion: eventing.knative.dev/v1alpha1
    kind: Channel
    name: knative-eventing-demo-channel
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1alpha1
      kind: Service
      name: knative-eventing-demo
```

# Buildpacks
No he conseguido hacer funcionar estos BuildTemplates. El build template esta en:  

```
kubectl apply -f https://raw.githubusercontent.com/knative/build-templates/master/buildpacks/cf.yaml
```

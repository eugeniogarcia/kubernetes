# Install

- Create a "minikube" external Hyper-V virtual switch.
- Put minikube.exe into a folder on a disk (e.g. k:\minikube).
- Add the folder to PATH.
- Create a folder on the same logical disk as the minikube.exe's folder (e.g. k:\minikube_home).
- Set MINIKUBE_HOME env var to the folder in p. 4
- CD to the minikube.exe's folder.

# Start minikube
//Without Hyper-V enabled
minikube start 

//With Hyper-v Enabled

minikube start --vm-driver="hyperv" --memory=4096 --cpus=4 --hyperv-virtual-switch="paraMiniKube" --v=7 --alsologtostderr

minikube start --vm-driver="hyperv" --memory=4096 --cpus=4 --hyperv-virtual-switch="paraMiniKube" --v=7 

//Check the status of the cluster
kubectl cluster-info

## NOTE
An External vswitch has to be available. We can create that on the Hyper-V Manager application. We have to select the Virtual Switch Manager action. There we can create a new external switch using the WiFi NIC of the computer. 

In this case i have named the virtual switch as paraMiniKube

# Quickstart
## Run an application
kubectl run hello-minikube --image=k8s.gcr.io/echoserver:1.4 --port=8080

## Services
//Public accessible
kubectl expose deployment hello-minikube --type=LoadBalancer

//Cluster accessible
kubectl expose deployment hello-minikube --type=NodePort
kubectl expose deployment hello-minikube --type=ClusterIP

# Config Docker credentials
When we want to fetch images from a private docker repository, we need to set up the credentials first on the Kubernetes cluster. Please refer to [Kubernetes page](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/):

kubectl create secret docker-registry micredencial --docker-server=https://cloud.docker.com/u/egsmartin/repository/ --docker-username=egsmartin --docker-password=Pupa1511 --docker-email=egsmartin@gmail.com

We can now see what is the secret configuration that has been created:

kubectl get secret micredencial --output=yaml

The value of the .dockerconfigjson field is a base64 representation of your Docker credentials:

kubectl get secret micredencial --output="jsonpath={.data.\.dockerconfigjson}"

On the yaml for the pod we need to specify these credentials that have to be used (see the example miServicio.yaml).

# Dashboard (very good!!!)
minikube dashboard

# Get information
## Cluster status
//Check the status of the cluster
kubectl cluster-info

## Get Node information
kubectl get nodes
kubectl get nodes -o wide

## Pods
//List of pods
kubectl get pod

//Gets additional information
kubectl get pods -o wide

//Describe a given pod
kubectl describe pod hello-minikube-79c7645c7c-4rm9f

//Gets a yaml with the definition and status of a given pod
kubectl get pod hello-minikube-79c7645c7c-4rm9f -o yaml

## Services
//List the services
kubectl get services
//This is an alias
kubectl get svc
//Gets extended information
kubectl get svc -o wide

//Url for the exposed service
minikube service hello-minikube --url

//Describe a service
kubectl describe service hello-minikube

## Replica Sets & Replication Controlers
//Get the replication controllers
kubectl get replicationcontrollers
kubectl get rc

//Get the replica sets
kubectl get rs 

//Describe a Replica Set
kubectl describe rs hello-minikube-79c7645c7c

# Create resources declaratively (yaml)
## Help 
//Get a description of the pod yaml
kubectl explain pods
//Further on this topic, we ask for a definition of the spec node withing the pods
kubectl explain pod.spec

## Create resource
kubectl create -f mise.yaml

//Create a service named kubia-http on the resource controller named Kubia
//Type LoadBalancer makes the service publicly available
//Type ClusterIp makes the service only accessible from within the cluster
kubectl expose rc kubia --type=LoadBalancer --name kubia-http

//Exposes as a public accessible service, the replica set hello-minikube-79c7645c7c
kubectl expose rs hello-minikube-79c7645c7c --type=LoadBalancer --name miservicio

//Exposes as a cluster only service, the replica set hello-minikube-79c7645c7c
kubectl expose rs hello-minikube-79c7645c7c --type=ClusterIP --name miintserv

# Labels
## Queries with Labels
//Shows the labels
kubectl get po --show-labels
//Shows specific labels
kubectl get po -L creation_method,env
//Gest the pods with an specific label
kubectl get po -l creation_method=manual

## Manage Labels
//Add a label to a pod
kubectl label po kubia-manual creation_method=manual
//Adds or updates a label in a pod
kubectl label po kubia-manual-v2 env=debug --overwrite

# Namespaces
## Create a namespace
With a yaml:

apiVersion: v1
kind: Namespace
metadata:
  name: custom-namespace

Or with a command:
kubectl create namespace custom-namespace

## Manage
//Retrieve pods with a given namespace:
kubectl get po --namespace kube-system  
  
# Annotations

kubectl annotate pod kubia-manual mycompany.com/someannotation="foo bar"

# Scale
//Scale the replication controller
kubectl scale rs hello-minikube-79c7645c7c  --replicas=2

#Logs
//Logs for a pod named miservicio
kubectl logs miservicio
//When the pod has more than one image, we need to specify also the image where to fetch the logs from
kubectl logs miservicio apinode

# Delete
## Delete service
kubectl delete service hello-minikube

## delete deployment
kubectl delete deployment hello-minikube

## Delete resources with a given label
kubectl delete po -l creation_method=manual

## Delete resources in a namespace
kubectl delete ns custom-namespace

## Delete all
kubectl delete po --all

## Stop minikube
minikube stop --alsologtostderr --v 7
minikube stop 

## Delete minikube
minikube delete

# Port forwarding
kubectl port-forward kubia-manual 8888:8080

# Deploy pod in a given node
spec:
  nodeSelector:
    gpu: "true"

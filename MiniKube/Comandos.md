# Install
- Create a "minikube" external Hyper-V virtual switch.
- Put minikube.exe into a folder on a disk (e.g. k:\minikube).
- Add the folder to PATH.

# Start
## Mas completo, pero excesivo
minikube start --extra-config=controller-manager.cluster-signing-cert-file="/var/lib/minikube/certs/ca.crt" --extra-config=controller-manager.cluster-signing-key-file="/var/lib/minikube/certs/ca.key" --extra-config=apiserver.admission-control="NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota" --kubernetes-version=v1.15.0 --memory=11264  --cpus=5

## Los certificados los dejamos configurados por defecto (es analogo al anterior)
minikube start --memory=11264 --cpus=5 --vm-driver "hyperv" --hyperv-virtual-switch "ParaMiniKube" --kubernetes-version=v1.15.0 --disk-size=20g --extra-config=apiserver.enable-admission-plugins="LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook"

## La version de Kubernetes por defecto (es analogo al anterior)
minikube start --memory=11264 --cpus=5 --vm-driver "hyperv" --hyperv-virtual-switch "ParaMiniKube" --disk-size=20g --extra-config=apiserver.enable-admission-plugins="LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook"

## Tamaño de disco por defecto (es analogo al anterior)
minikube start --memory=11264 --cpus=5 --vm-driver "hyperv" --hyperv-virtual-switch "ParaMiniKube" --extra-config=apiserver.enable-admission-plugins="LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook"

## Configuracion que usamos
minikube start --extra-config=apiserver.admission-control="NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota" --memory=11264  --cpus=5

# Comandos
minikube status

minikube addons list
minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable heapster

minikube service list

minikube addons open heapster

minikube dashboard
minikube dashboard — url

minikube ip

minikube ssh
ssh -i C:/Users/Eugenio/.minikube/machines/minikube/id_rsa docker@192.168.1.150
username: "docker", password: "tcuser"
Podemos ver estas propiedades en:
C:\Users\Eugenio\.minikube\machines\minikube\config.json
El root es root y sin contraseña

#Comandos basicos para configurar kubectl
kubectl config use-context minikube
kubectl config current-context
kubectl version
kubectl cluster-info
kubectl api-versions



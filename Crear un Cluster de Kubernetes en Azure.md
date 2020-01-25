# Setting up a single master Kubernetes cluster on Azure using kubeadm

By the end of this guide, you will have a Kubernetes cluster on Azure with one master and one worker node. You will know how to add more worker nodes to the cluster.

## Procedure

You will start from __creating a [base image](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) of a virtual machine__ that will __contain [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/), [containerd](https://github.com/containerd/containerd), kubelet and kubectl__. The __image will be used__ to __create 2 virtual machines__:

- one for Kubernetes master node 
- one for Kubernetes worker node

After that, you will __use kubeadm__ to __create__ a __single [control-plane](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) Kubernetes cluster__.

## Creating a virtual machine

Log into Azure:

```sh
az login
```

Create a resource group:

```sh
az group create --name KubernetesTestCluster --location westeurope
```

Create a VM. We create the ssh public key and place it in `~/.ssh/id_rsa.pub`.

```sh
az vm create \
  --resource-group KubernetesTestCluster \
  --name base-vm \
  --image UbuntuLTS \
  --size Standard_B2s \
  --admin-username azuser \
  --tags name=base-vm \
  --ssh-key-value ~/.ssh/id_rsa.pub
```

Connect via ssh to the vm we have just created:

```sh
ssh azuser@<publicIpAddress>
```

Change tu super user:

```sh
sudo su -
```

## Installing containerd to base-vm

These instructions are based on Kubernetes documentation. If you have any questions, please read [Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/).

Will use __containerd__ as a Kubernetes container runtime. However there are several container runtimes listed in [Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/), and you can use any of them if you want.

```sh
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
```

```sh
modprobe overlay br_netfilter
```

```sh
# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
```

```sh
sysctl --system
```

```sh
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common
```

```sh
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
```

```sh
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
```

```sh
apt-get update && apt-get install -y containerd.io
```

```sh
mkdir -p /etc/containerd && containerd config default > /etc/containerd/config.toml
```

```sh
# since UbuntuLTS uses systemd as the init system
sed -i 's/systemd_cgroup = false/systemd_cgroup = true/' /etc/containerd/config.toml
```

## Installing kubeadm to base-vm

These instructions are based on Kubernetes documentation. If you have any questions, please read [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

```sh
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```

```sh
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
```

```sh
apt-get update && apt-get install -y kubelet kubeadm kubectl && apt-mark hold kubelet kubeadm kubectl
```

```sh
# since containerd is configured to use the systemd cgroup driver
echo 'KUBELET_EXTRA_ARGS=--cgroup-driver=systemd' > /etc/default/kubelet
```

__Make sure that swap is disabled in /etc/fstab__. Check bellow to see how to do it.

## Creating a base VM image from base-vm

We´ll create an [image](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-custom-images). 

Deprovision the virtual machine, exit from the root environment and close the SSH session.

```sh
waagent -deprovision+user

WARNING! The waagent service will be stopped.
WARNING! Cached DHCP leases will be deleted.
WARNING! root password will be disabled. You will not be able to login as root.
WARNING! /etc/resolv.conf will NOT be removed, this is a behavior change to earlier versions of Ubuntu.
WARNING! azuser account and entire home directory will be deleted.
Do you want to proceed (y/n)y
```

Then we exit from the console. In Powershell we issue the following commands:

- Deallocate the VM:

```sh
az vm deallocate --resource-group KubernetesTestCluster --name base-vm
```

- Update the status of the VM so that Azure knows that this vm is now generalized:

```sh
az vm generalize --resource-group KubernetesTestCluster --name base-vm
```

- Create the image

```sh
az image create --resource-group KubernetesTestCluster --name base-vm-image --source base-vm
```

If we run the following, we will get the details of the image we have just created:

```sh
az image list --resource-group KubernetesTestCluster 
```

## Deleting unused resources

Now that we have the image, we no longer need the virtual machine that was used to create it. We should delete the virtual machine to avoid being charged for resources we don't use. Unfortunately at the moment of writing, deleting a virtual machine using CLI in Azure does not delete all dependent resources that were automatically created for the machine (for instance, disks and network interfaces).

When we created the virtual machine we applied a tag to every resource it created via `--tags name=base-vm`. We can now use `az resource list --tag to find all dependent resources that need to be deleted.

```sh
az resource list --tag name=base-vm
```

We delete the vm:

```sh
az vm delete --resource-group KubernetesTestCluster --name base-vm
```

The previous command deleted the VM. Now we need to delete everything else that was created with the VM and that is no longer needed - network security group, public ip, virtual network, storage account, ...:

```sh
az resource delete --ids $(az resource list --tag name=base-vm --query "[].id" -otsv)
```

We can check that all the resources are now deleted:

```sh
az resource list --tag name=base-vm                                                   

[]
```

## Initializing your control-plane node

To create a new virtual machine for your control-plane node using the prepared base-vm-image

```sh

az vm create \
   --resource-group KubernetesTestCluster \
   --name master1 \
   --image base-vm-image \
   --size Standard_B2s \
   --admin-username azuser \
   --ssh-key-value ~/.ssh/id_rsa.pub
```

We use ssh to connect to the VM:

```sh
sudo su -
```

We configure bash completion:

```sh
mkdir -p $HOME/.kube
```

```sh
kubectl completion bash > ~/.kube/completion.bash.inc
```

```sh
printf "
# Kubectl shell completion
source '$HOME/.kube/completion.bash.inc'
" >> $HOME/.bash_profile
```

```sh
source $HOME/.bash_profile
```

## Initialize the control plane:

```sh
kubeadm init --pod-network-cidr=10.244.0.0/16
```

We should see something like this:

```sh
[init] Using Kubernetes version: v1.17.0
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
...

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join <control-plane-host>:<control-plane-port> --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

Where `token` is the actual token that has to be used. For example, in my case i got the following:

```sh
kubeadm join 10.0.0.4:6443 --token 1u9kyl.zln914vwtyzgu0yz \
    --discovery-token-ca-cert-hash sha256:019c47ef56b4f79828a6c81af25a54b512336cb0f26df400a9ffd6f05af3c85f
```

Then we have to configure kubectl and run kubectl cluster-info to verify that Kubernetes master is running:

```sh
mkdir -p $HOME/.kube
```

```sh
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

```sh
sudo chown $(id -u):$(id -g) $HOME/admin.conf
```

```sh
export KUBECONFIG=$HOME/admin.conf
```

```sh
kubectl cluster-info

Kubernetes master is running at https://10.0.0.4:6443
KubeDNS is running at https://10.0.0.4:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Install pod network addon:

```sh
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

## Adding a worker node to the cluster

Create a new virtual machine for a worker node using the prepared base-vm-image

```sh
az vm create \
   --resource-group KubernetesTestCluster \
   --name worker1 \
   --image base-vm-image \
   --size Standard_B2s \
   --admin-username azuser \
   --ssh-key-value ~/.ssh/id_rsa.pub
```

Connect via ssh:

```sh
ssh azuser@<publicIpAddress>
```

Run the kubeadm join command that you saw in the output of kubeadm init above

```sh
sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

In my case, the command that was run was:

```sh
sudo su -

kubeadm join 10.0.0.4:6443 --token 1u9kyl.zln914vwtyzgu0yz --discovery-token-ca-cert-hash sha256:019c47ef56b4f79828a6c81af25a54b512336cb0f26df400a9ffd6f05af3c85f
```

By default, __tokens expire after 24 hours__. If you are joining a node to the cluster after the current token has expired, you can create a new token by running kubeadm token create on the master node.

## Smoke testing

To verify that all nodes are Ready and all pods are Running, connect to the __master__ using ssh, run as `su`:

```sh
sudo su -
```

Check the nodes:

```sh
kubectl get nodes -o wide


NAME      STATUS   ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
master1   Ready    master   27m     v1.17.2   10.0.0.4      <none>        Ubuntu 18.04.3 LTS   5.0.0-1028-azure   containerd://1.2.10
worker1   Ready    <none>   5m54s   v1.17.2   10.0.0.5      <none>        Ubuntu 18.04.3 LTS   5.0.0-1028-azure   containerd://1.2.10
```

Lets see the pods:

```sh
kubectl get pods --all-namespaces -o wide


NAMESPACE     NAME                              READY   STATUS    RESTARTS   AGE     IP           NODE      NOMINATED NODE   READINESS GATES
kube-system   coredns-6955765f44-5pmgw          1/1     Running   0          24m     10.244.0.4   master1   <none>           <none>
kube-system   coredns-6955765f44-lc2qp          1/1     Running   0          24m     10.244.0.3   master1   <none>           <none>
kube-system   etcd-master1                      1/1     Running   0          24m     10.0.0.4     master1   <none>           <none>
kube-system   kube-apiserver-master1            1/1     Running   0          24m     10.0.0.4     master1   <none>           <none>
kube-system   kube-controller-manager-master1   1/1     Running   0          24m     10.0.0.4     master1   <none>           <none>
kube-system   kube-flannel-ds-amd64-qpbbl       1/1     Running   0          3m16s   10.0.0.5     worker1   <none>           <none>
kube-system   kube-flannel-ds-amd64-xcmdq       1/1     Running   0          18m     10.0.0.4     master1   <none>           <none>
kube-system   kube-proxy-dffbs                  1/1     Running   0          3m16s   10.0.0.5     worker1   <none>           <none>
kube-system   kube-proxy-zpm2n                  1/1     Running   0          24m     10.0.0.4     master1   <none>           <none>
kube-system   kube-scheduler-master1            1/1     Running   0          24m     10.0.0.4     master1   <none>           <none>
```

# Procedures

## Make sure that swap is disabled in /etc/fstab

Before actually disabling swap space, first you need to visualize your memory load degree and then identify the partition that holds the swap area, by issuing the below commands.

```sh
free -h
```

Look for Swap space used size. If the used size is 0B or close to 0 bytes, it can be assumed that swap space is not used intensively and can be safety disabled.

```sh
              total        used        free      shared  buff/cache   available
Mem:           3.8G        318M        2.6G        680K        966M        3.3G
Swap:            0B          0B          0B
```

In my case it was disabled, but suppose it was not. Then, next, issue following blkid command, look for TYPE=”swap” line in order to identify the swap partition, as shown in the below screenshot.

```sh
blkid 
```

The output will be something like this. In my case i do not get any `TYPE="swap"` because swap was disabled:

```sh
/dev/sda1: LABEL="cloudimg-rootfs" UUID="61962a4a-1065-4707-8222-2666c0bd6ddc" TYPE="ext4" PARTUUID="29b6476e-53b5-40e0-8120-8b8e20da0d6d"
/dev/sda15: LABEL="UEFI" UUID="DE84-9309" TYPE="vfat" PARTUUID="958c1559-51dd-4ef0-81ba-650c421745a3"
/dev/sdb1: UUID="fa6979fc-4f71-4434-b611-690ad7d5af3d" TYPE="ext4" PARTUUID="f79c7bde-01"
/dev/sda14: PARTUUID="8b2fa660-25d3-4674-bcef-44f8b0fba5e3"
```

Issue the following lsblk command to search and identify the [SWAP] partition.

```sh
lsblk
```

It will show the `SWAP` partitition as a `MOUNTPOINT`. In my case it does not show up because swap is disabled:

```sh
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda       8:0    0   30G  0 disk
+-sda1    8:1    0 29.9G  0 part /
+-sda14   8:14   0    4M  0 part
+-sda15   8:15   0  106M  0 part /boot/efi
sdb       8:16   0    8G  0 disk
+-sdb1    8:17   0    8G  0 part /mnt
sr0      11:0    1  628K  0 rom
```

Lets suppose we had a `SWAP` partition and we get this with the `lsblk` command:

```sh
NAME    			MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda       			8:0    0   30G  0 disk
+-sda1    			8:1    0 29.9G  0 part /
+-sda2   			8:14   0    4M  0 part
	+-centos-root	8:15   0  106M  0 lvm /
	+-centos-swap   8:15   0  106M  0 lvm [SWAP]
```

Then we will disable the swap as follows:

```sh
swapoff /dev/mapper/centos-swap
```

Or disable all swaps from /proc/swaps

```sh
swapoff -a
```

If we check again:

```sh
free -h

              total        used        free      shared  buff/cache   available
Mem:           3.8G        318M        2.6G        680K        966M        3.3G
Swap:            0B          0B          0B
```

In order to permanently disable swap space in Linux, open /etc/fstab file, search for the swap line and comment the entire line by adding a # (hashtag) sign in front of the line.

```sh
vi /etc/fstab
```

## Create a custom image of an Azure VM with the Azure CLI

Custom images are like marketplace images, but you create them yourself. Custom images can be used to bootstrap configurations such as preloading applications, application configurations, and other OS configurations.

- Deprovision and generalize VMs
- Create a custom image
- Create a VM from a custom image
- List all the images in your subscription
- Delete an image

### Create a custom image

To create an image of a virtual machine, you need to prepare the VM by deprovisioning, deallocating, and then marking the source VM as generalized. Once the VM has been prepared, you can create an image.

#### Deprovision the VM

Deprovisioning generalizes the VM by removing machine-specific information. This generalization makes it possible to deploy many VMs from a single image. __During deprovisioning__, the __host name is reset to localhost.localdomain__. __SSH host keys__, __nameserver configurations__, __root password__, and __cached DHCP leases__ are also __deleted__. Deprovisioning and marking the VM as generalized will make source VM unusable, and it cannot be restarted.

To deprovision the VM, use the Azure VM agent (__waagent__). The Azure VM agent is installed on the VM and __manages provisioning and interacting with the Azure Fabric Controller__.

Connect to your VM using SSH and run the command to deprovision the VM. With the +user argument, the last provisioned user account and any associated data are also deleted.

```sh
sudo waagent -deprovision+user -force
```

#### Deallocate and mark the VM as generalized

To create an image, the VM needs to be deallocated.

```sh
az vm deallocate --resource-group myResourceGroup --name myVM
```

Finally, set the state of the VM as generalized with az vm generalize so the Azure platform knows the VM has been generalized. You can only create an image from a generalized VM.

```sh
az vm generalize --resource-group myResourceGroup --name myVM
```

#### Create the image

Now you can create an image of the VM. The following example creates an image named _myImage_ from a VM named _myVM_.

```sh
az image create --resource-group myResourceGroup --name myImage --source myVM
```

### Create VMs from the image

Now that you have an image, you can create one or more new VMs from the image using az vm create. The following example creates a VM named myVMfromImage from the image named myImage.

```sh
az vm create \
    --resource-group myResourceGroup \
    --name myVMfromImage \
    --image myImage \
    --admin-username azureuser \
    --generate-ssh-keys
```

### Image management

List all images by name in a table format.

```sh
az image list --resource-group myResourceGroup
```

Delete an image

```
az image delete --name myOldImage --resource-group myResourceGroup
```

## Connect to a VM using an SSH Agent

In my setup i have created the following:

- Master node - following this guide
- Two Worker nodes - following this guide

I have attached a public ip to the master node and to one of the workers. To connect to the worker that does not have a public ip i have used ssh-agent. In the case of windows the procedure is:

- start `pageant.exe`
- add the private key we want to forward to `pageant.exe`
- start `putty`. In the Authentication - `Connection->SSH->Auth` - enable the check `Allow agent forwarding`
- connect via putty to the worker node that has a public ip. Once there, do ssh to the other worker node

## Run from local machine

In the master node, in folder `/etc/kubernetes`, take a copy of the `admin.conf` file to your local machine.

In `/etc/kubernetes/pik` we have all the certificates used by kubernetes. Open the `apiserver.crt`. In the Subject Alternative names take a look at the different DNS entries configured. Will pick one, in our case we chose `kubernetes.default.svc.cluster.local`.

Update the `admin.conf` file, specifically

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJd01ERXlOVEV6TkRjd01sb1hEVE13TURFeU1qRXpORGN3TWxvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBSzNxCnBpKzhFTVRUTmhKSnZyUk5IcXMrN3JWdGNMS0tRUVIxeFI1UW1BMW8rYXFaaExjQjZ5ZWxUdEVMK093eFlCajYKMWtGV0NJaGhQUlZPV3dBTTJmUUtjTThmTGhQRmRoRVJCSkJOQjZxakFQRHg0amFIeTNSU093YUhnNmhWNDQxbQpWZ0RCU2hjOS8wZDBrZCsvNEFHMDllbXBDYjhnRVVvcXVDQnBxMVdsVnJqNUdld09JWDR1YkU0KzNNdDBQVVIwCjJZRkpkenpUZlVEQUhPYmFWZ25nb3Nnb1RsS3BvakNkYXQ5cDR3SFh4OWNoU1o1dTl5b2l1ZWQwUU96Vkk5TWYKS1VwUWRuem53QUxjaldhdjg2ZDRjN2ZrK0RKZmx4d0N4TWtXWkFuQk4zcGZaUHBpQjdmelhGZDlQTjcxQlJBWQpldm01amRNeWtLbVVnaXNRWWNrQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFJNU0yUEFvWDRtQ1RjNmsvWVNZOUJiaWRnODgKa3huZmkrdC9jOTNGT2cwd0UrNmFsYUc4MzRqZHNTR1A1Um90ZXhEbC9DUFlzTUlJWHFqa1A3UzAvTUZ0N056QgpTY1U2NUkxTk5qNXhUR3o0aytCa1hZRFoyZGRiZnZPdVkrQlBndXJNcE1zNTJNWCtsb3FzWitrVU1jdG9VMlB1CnFURVpSQ1lOQ3Ezd05mbUU3eEtieHJqK21XSlFOL1Y4THZKK0M2MnFENWZTY3Q1RUg3Ry9McmV1cEFJbDg0TngKVTFqWUFwRCtvRFZSK1RmTi9mQ3BBdFBXcWpIRTdwaHFIT05TYkZzTllvZ3RUUEhvRnhwbEdXR0FVU1BCajJsegpxeHFMeEZDdXNCSkhVTEdrOE11N2JMbVBteFZnR1pXQXZFQlFPMFBBa3djODlIYkNSNlpQN2lOa2JUTT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
    server: https://10.0.0.4:6443
  name: kubernetes
contexts:

...
```

Is changed so the server address uses the DNS entry we picked from the certificate:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJd01ERXlOVEV6TkRjd01sb1hEVE13TURFeU1qRXpORGN3TWxvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBSzNxCnBpKzhFTVRUTmhKSnZyUk5IcXMrN3JWdGNMS0tRUVIxeFI1UW1BMW8rYXFaaExjQjZ5ZWxUdEVMK093eFlCajYKMWtGV0NJaGhQUlZPV3dBTTJmUUtjTThmTGhQRmRoRVJCSkJOQjZxakFQRHg0amFIeTNSU093YUhnNmhWNDQxbQpWZ0RCU2hjOS8wZDBrZCsvNEFHMDllbXBDYjhnRVVvcXVDQnBxMVdsVnJqNUdld09JWDR1YkU0KzNNdDBQVVIwCjJZRkpkenpUZlVEQUhPYmFWZ25nb3Nnb1RsS3BvakNkYXQ5cDR3SFh4OWNoU1o1dTl5b2l1ZWQwUU96Vkk5TWYKS1VwUWRuem53QUxjaldhdjg2ZDRjN2ZrK0RKZmx4d0N4TWtXWkFuQk4zcGZaUHBpQjdmelhGZDlQTjcxQlJBWQpldm01amRNeWtLbVVnaXNRWWNrQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFJNU0yUEFvWDRtQ1RjNmsvWVNZOUJiaWRnODgKa3huZmkrdC9jOTNGT2cwd0UrNmFsYUc4MzRqZHNTR1A1Um90ZXhEbC9DUFlzTUlJWHFqa1A3UzAvTUZ0N056QgpTY1U2NUkxTk5qNXhUR3o0aytCa1hZRFoyZGRiZnZPdVkrQlBndXJNcE1zNTJNWCtsb3FzWitrVU1jdG9VMlB1CnFURVpSQ1lOQ3Ezd05mbUU3eEtieHJqK21XSlFOL1Y4THZKK0M2MnFENWZTY3Q1RUg3Ry9McmV1cEFJbDg0TngKVTFqWUFwRCtvRFZSK1RmTi9mQ3BBdFBXcWpIRTdwaHFIT05TYkZzTllvZ3RUUEhvRnhwbEdXR0FVU1BCajJsegpxeHFMeEZDdXNCSkhVTEdrOE11N2JMbVBteFZnR1pXQXZFQlFPMFBBa3djODlIYkNSNlpQN2lOa2JUTT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
    server: https://kubernetes.default.svc.cluster.local:6443
  name: kubernetes
contexts:

...
```

Update the `hosts` file so that the DNS is solved into the public ip:

```yaml
# For Azure control plane
51.136.77.7	kubernetes.default.svc.cluster.local
```

In our case `51.136.77.7` was the public ip assigned by Azure.

In Azure we created a __NAT__ rule in our Load Balancer, so that `6443` is mapped to our master node. In the NSG of our master node we also have to open this port.

With that:

```sh
PS [EUGENIO] >kubectl --kubeconfig .\admin.conf get po --all-namespaces


NAMESPACE     NAME                              READY   STATUS    RESTARTS   AGE
kube-system   coredns-6955765f44-5pmgw          1/1     Running   1          6h26m
kube-system   coredns-6955765f44-lc2qp          1/1     Running   1          6h26m
kube-system   etcd-master1                      1/1     Running   1          6h26m
kube-system   kube-apiserver-master1            1/1     Running   1          6h26m
kube-system   kube-controller-manager-master1   1/1     Running   1          6h26m
kube-system   kube-flannel-ds-amd64-4gzzn       1/1     Running   2          5h16m
kube-system   kube-flannel-ds-amd64-qpbbl       1/1     Running   1          6h5m
kube-system   kube-flannel-ds-amd64-xcmdq       1/1     Running   1          6h20m
kube-system   kube-proxy-dffbs                  1/1     Running   1          6h5m
kube-system   kube-proxy-tqg9q                  1/1     Running   1          5h16m
kube-system   kube-proxy-zpm2n                  1/1     Running   1          6h26m
kube-system   kube-scheduler-master1            1/1     Running   1          6h26m
```
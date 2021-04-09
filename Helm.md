# Install helm

Guía rápida de instalación de [Helm](https://helm.sh/docs/intro/quickstart/).

Añadimos el repositorio:

```ps
helm repo add stable https://charts.helm.sh/stable
```

Podemos consultar el contenido del repositorio:

```ps
helm search repo stable
```

## Instalar una Chart

Podemos instalar una chart:

```ps
helm repo update

helm install stable/mysql --generate-name

WARNING: This chart is deprecated
NAME: mysql-1617959064
LAST DEPLOYED: Fri Apr  9 11:04:25 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql-1617959064.default.svc.cluster.local

To get your root password run:

    MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default mysql-1617959064 -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)

To connect to your database:

1. Run an Ubuntu pod that you can use as a client:

    kubectl run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il

2. Install the mysql client:

    $ apt-get update && apt-get install mysql-client -y

3. Connect using the mysql cli, then provide your password:
    $ mysql -h mysql-1617959064 -p

To connect to your database directly from outside the K8s cluster:
    MYSQL_HOST=127.0.0.1
    MYSQL_PORT=3306
```

## Ver que se ha instalado

Podemos ver que se ha instalado con Helm:

```ps
helm ls
```

## Desinstalar

Podemos desinstalar:

```ps
helm uninstall mysql-1617959064
```

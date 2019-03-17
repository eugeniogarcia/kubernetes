# Copiar logs desde y hacia un contenedor
Copiar desde un contenedor a la máquina local:  
```
kubectl cp foo-pod:/var/log/foo.log foo.log
```
Copiar desde la máquina local al contenedor:  
```
kubectl cp localfile foo-pod:/etc/remotefile
```

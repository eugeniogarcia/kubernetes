# Crea una imagen
```
docker build -t hola .  

docker run --name contenedor-hola -p 8080:8080 -d hola
```
# Consulta las imagenes
```
docker images  
docker ps
```
## Inspecciona  
Inspecciona un contenedor en ejecución:  
```  
docker inspect contenedor-hola  
```
Inspecciona una imagen:  
```
docker inspect hola  
```
## Ejecuta una instruccion en el contenedor  
```
docker exec -it contenedor-hola bash  
```
List the processes running in the container:  
```
ps aux
ps aux | grep hello.js
```
## Para el contenedor  
```
docker stop contenedor-hola  
docker rm contenedor-hola  
```
## Push una imagen
Para publicar la imagen en el [repositorio de Docker](http://hub.docker.com):  
- Creamos un tag:  
```  
docker tag hola egsmartin/hola  
docker images  
```
- Publicamos la imagen:  
```  
docker login
docker push egsmartin/hola  
```
Procedemos a ejecutar la imagen que hemos subido al repo. Docker la descargara primero:  
```
docker run -p 8080:8080 -d egsmartin/hola
```

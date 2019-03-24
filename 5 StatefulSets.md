# Introducción
Los Persistent Volumes (PV) que hemos visto se definen en un Pod. Todas las instancias de un Pod usaran el mismo PV. Si quisieramos que cada Pod tuviera acceso exclusivo a almacenamiento, habrá que buscar una alternativa:  
- Crear dentro del PV varios directorios, de modo que cada directorio sea exclusivo para cada Pod. Esto require de una coordinación, que cada instancia sepa "quien es", y que trabaje de forma diferente a las anteriores  
- Crear Pods individualmente, sin gobernarlos con un RS  
- Crear un tantos RS como Pods haya que crear. Asi tenemos el elemento de feedback, pero cada Pod puede tener su almacenamiento exclusivo  

## IP
Otra cosa que necesitaremos es poder localizar el servicio en una dirección que no cambie cuando el Pod se schedulea en otro nod. El servicio nos ofrece esta capacidad, pero si tuvieramos un cada Pod gestionado por separado con un RS, tendríamos que crear un servicio para cada Pod, para que asi cada Pod tuviera su propia identidad:  

![manualstatefull.png](Imagenes\manualstatefull.png)
# StatefulSet
El Statefulset es un recurso que nos proporciona esta funcionalidad búsca implementar la funcionalidad antes descrita de forma más eficaz.  
Cuando un Pod stateful muere, necesitamos que se reconstruya con la misma identidad, y con los mismos datos - estado -, y con el mismo nombre, aunque el scheduler lo resurrecte en otro nodo.  
Los pods que se crean con este recurso tienen un nombre previsible. En esta imagen podemos ver en la izquierda un RS y un set de Pods tradicionales, y en la derecha podemos ver el equivalente creados con un Statefulset:  

![PodsEnStatefulSets.png](Imagenes\PodsEnStatefulSets.png)
## Governing Service
Unlike regular pods, stateful pods sometimes need to be addressable by their hostname, whereas stateless pods usually don’t

with stateful pods, you usually want to operate on a specific pod from the group, because they differ from each other

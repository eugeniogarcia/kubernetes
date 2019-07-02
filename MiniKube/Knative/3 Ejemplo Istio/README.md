#Configura las variables de entorno para configurar el ingress Gateway
Get-ChildItem Env:

$Env:INGRESS_PORT = kubectl -n istio-system get service istio-ingressgateway -o jsonpath="{.spec.ports[?(@.name=='http2')].nodePort}"
Get-ChildItem  Env:INGRESS_PORT

$Env:SECURE_INGRESS_PORT=kubectl -n istio-system get service istio-ingressgateway -o jsonpath="{.spec.ports[?(@.name=='https')].nodePort}"
Get-ChildItem  Env:SECURE_INGRESS_PORT

$Env:INGRESS_HOST="127.0.0.1"
Get-ChildItem  Env:INGRESS_HOST

Get-ChildItem Env:|%{if($_.Key -like "*INGRESS*"){$_}}

$Env:GATEWAY_URL="$Env:INGRESS_HOST"+":"+"$Env:INGRESS_PORT"


#Destination rules
kubectl get destinationrules -o yaml
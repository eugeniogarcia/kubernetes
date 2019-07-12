kubectl label namespace default istio-injection=enabled

kubectl get namespace -L istio-injection

kubectl apply -f ./bookinfo.yaml

kubectl apply -f ./bookinfo-gateway.yaml

kubectl apply -f ./bookinfo-virtualservices.yaml

kubectl apply -f ./bookinfo-destinationrule.yaml
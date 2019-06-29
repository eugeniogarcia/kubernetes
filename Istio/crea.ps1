kubectl label namespace default istio-injection=enabled

kubectl apply -f ./bookinfo.yaml

kubectl apply -f ./bookinfo-gateway.yaml
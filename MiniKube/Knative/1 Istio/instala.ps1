kubectl apply --filename ./istio-crds.yaml

kubectl apply --filename ./istio.yaml

kubectl label namespace default istio-injection=enabled

echo "kubectl get pods --namespace istio-system"
kubectl get pods --namespace istio-system
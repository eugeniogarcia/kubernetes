kubectl apply --selector knative.dev/crd-install=true --filename https://github.com/knative/serving/releases/download/v0.7.0/serving.yaml --filename https://github.com/knative/build/releases/download/v0.7.0/build.yaml --filename https://github.com/knative/eventing/releases/download/v0.7.0/release.yaml    --filename https://github.com/knative/serving/releases/download/v0.7.0/monitoring.yaml


kubectl apply --filename https://github.com/knative/serving/releases/download/v0.7.0/serving.yaml --selector networking.knative.dev/certificate-provider!=cert-manager --filename https://github.com/knative/build/releases/download/v0.7.0/build.yaml --filename https://github.com/knative/eventing/releases/download/v0.7.0/release.yaml --filename https://github.com/knative/serving/releases/download/v0.7.0/monitoring.yaml

echo "quitar elastic search"
kubectl delete -f .\monitoring-logs-elasticsearch.yaml


echo "kubectl get pods --namespace knative-serving"
kubectl get pods --namespace knative-serving

echo "kubectl get pods --namespace knative-build"
kubectl get pods --namespace knative-build

echo "kubectl get pods --namespace knative-eventing"
kubectl get pods --namespace knative-eventing

echo "kubectl get pods --namespace knative-monitoring"
kubectl get pods --namespace knative-monitoring
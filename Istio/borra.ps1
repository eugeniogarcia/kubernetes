$a=kubectl get destinationrules -o name
$a+=kubectl get virtualservices -o name
$a+=kubectl get gateways -o name

foreach ($b in $a){
	kubectl delete $b
}

kubectl delete -f .\bookinfo.yaml
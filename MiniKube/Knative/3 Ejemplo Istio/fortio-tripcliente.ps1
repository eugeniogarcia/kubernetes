kubectl exec -it fortio-deploy-5947d85c75-bkzwd -c fortio /usr/bin/fortio -- load -c 2 -qps 0 -n 20 -loglevel Warning -curl http://httpbin:8000/get


kubectl exec -it fortio-deploy-5947d85c75-bkzwd -c istio-proxy -- sh -c 'curl localhost:15000/stats | grep httpbin | grep pending'




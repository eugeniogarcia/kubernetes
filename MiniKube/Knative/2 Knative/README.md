Cuando hacemos la instalacion por defecto de Knative, instala todos los componentes relativos al ![monitoring](https://knative.dev/v0.3-docs/serving/installing-logging-metrics-traces/#elasticsearch-and-kibana). 

ElasticSearch consume bastantes recursos, asi que lo desinstalo

kubectl delete -f .\monitoring-logs-elasticsearch.yaml
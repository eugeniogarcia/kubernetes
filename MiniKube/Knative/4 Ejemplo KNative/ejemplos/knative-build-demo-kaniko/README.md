# Kaniko
We can build a docker image with Kaniko. Kaniko provides an image that is used to build docker images:  

```
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: docker-build
spec:
  serviceAccountName: build-bot
  source:
    git:
      url: https://github.com/dgageot/hello.git
      revision: master
  steps:
  - name: build-and-push
    image: gcr.io/kaniko-project/executor:v0.1.0
    args:
    - --dockerfile=/workspace/Dockerfile
    - --destination=docker.io/egsmartin/hello-nginx:latest
```  

# Template
Instead of using it raw as before, we can create a template with all the steps to build the image:  

```
apiVersion: build.knative.dev/v1alpha1
kind: BuildTemplate
metadata:
  name: docker-build
spec:
  parameters:
  - name: IMAGE
    description: Where to publish the resulting image.
  - name: DIRECTORY
    description: The directory containing the build context.
    default: workspace
  - name: DOCKERFILE_NAME
    description: The name of the Dockerfile
    default: Dockerfile
  steps:
  - name: build-and-push
    image: gcr.io/kaniko-project/executor:latest
    args:
    - --dockerfile=/${DIRECTORY}/${DOCKERFILE_NAME}
    - --destination=${IMAGE}
```

## Use the Template

Now, the Build can be simplified by referencing the template and by
providing the right values for each parameter.

```
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: docker-build-hello
spec:
  serviceAccountName: knative-build
  source:
    git:
      url: https://github.com/dgageot/hello.git
      revision: master
  template:
    name: docker-build
    arguments:
    - name: IMAGE
      value: gcr.io/[PROJECT-NAME]/hello-nginx
```

## Run the Templated Build
Run the build:

```bash
kubectl apply -f docker-build/build-hello.yaml
```

The build is running:

```bash
kubectl get builds
```

Tail the logs with:

```bash
logs docker-build-hello
```

## Kaniko BuildTemplate
We have a ![kaniko template](https://raw.githubusercontent.com/knative/build-templates/master/kaniko/kaniko.yaml) available which does what we have essentially done with our template.  

```
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: knative-build-demo
spec:
  serviceAccountName: build-bot
  source:
    git:
      url: https://github.com/dgageot/hello.git
      revision: master
  template:
    name: kaniko
    arguments:
    - name: IMAGE
      value: docker.io/egsmartin/hello-nginx:latest
```
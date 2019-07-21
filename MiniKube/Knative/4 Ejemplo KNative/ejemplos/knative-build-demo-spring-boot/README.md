# Knative Build - Java application

The previous tutorial taught you how to build and push a Docker image from a Dockerfile, using Knative Build and Kaniko.

Let's try something different and build a [Java Spring Boot web application](https://github.com/dgageot/hello-jib), without Docker. It will still produce a Docker image at the end, though.

## What am I going to learn?

 1. You are going to use Knative Build with [Jib](https://github.com/GoogleContainerTools/jib), another open-source project from Google. Jib is a maven and gradle plugin that knows how to produce a Docker image from Java sources. It's easy to use as a Knative Build step.

 2. You will learn how to decrease the build duration by configuring a build cache.

## Jib and Knative Build
```
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: jib
spec:
  serviceAccountName: knative-build
  source:
    git:
      url: https://github.com/dgageot/hello-jib.git
      revision: master
  steps:
  - name: build-and-push
    image: gcr.io/cloud-builders/mvn
    args: ["compile", "jib:build", "-Dimage=gcr.io/[PROJECT-NAME]/hello-jib"]
```


**Maven**

This time, we are using [Maven](https://maven.apache.org/) to do the actual build.
We use the `gcr.io/cloud-builders/mvn` image that is one of the Google
[curated images](https://github.com/GoogleCloudPlatform/cloud-builders).

From the arguments, Maven knows it has to compile the Java sources and then call Jib to produce a Docker image.

```
- name: build-and-push
  image: gcr.io/cloud-builders/mvn
  args: ["compile", "jib:build", "-Dimage=gcr.io/[PROJECT-NAME]/hello-jib"]
```

## Clean builds are slow

If you run the build a second time, you'll see that it downloads lots of files
that were already downloaded the first time. It's because Maven is starting
the build from the sources and nothing else.

That makes the build more reproducible but also slower.

Most of the time, it's safe to share the artifacts that Maven downloads across builds.
And it usually makes a build much faster.

**We need a cache**

Because Knative Build is native to Kubernetes, it can leverage [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
to share a cache across builds. All we have to do is make some changes to the `build.yaml`.

**Click the `Continue` button to configure this cache...**

## Update the Build manifest

We are going to use a more elaborate version of the Build manifest that looks like that:

```
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: jib-cache
spec:
  serviceAccountName: knative-build
  source:
    git:
      url: https://github.com/dgageot/hello-jib.git
      revision: master
 
  steps:
  - name: build-and-push
    image: gcr.io/cloud-builders/mvn
    args: ["compile", "jib:build", "-Dimage=gcr.io/[PROJECT-NAME]/hello-jib"]
    volumeMounts:
    - name: mvn-cache
      mountPath: /root/.m2

  volumes:
  - name: mvn-cache
    persistentVolumeClaim:
      claimName: cache
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: cache
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 8Gi
```

This configuration does two things:

 + It creates a Persistent Volume to be shared by builds
 + It mounts this volume in `/root/.m2` during a build so that files written there will be available to next build.
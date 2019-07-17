# Start from a Debian image with the latest version of Go installed
# and a workspace (GOPATH) configured at /go.
FROM golang

# Copy the local package files to the container's workspace.
ADD . /knative-helloworld-env

# Move into the directory with out code and build it
WORKDIR /knative-helloworld-env
RUN go build 

# Run the outyet command by default when the container starts.
ENTRYPOINT ./knative-helloworld-env

# Document that the service listens on port 8080.
EXPOSE 8080
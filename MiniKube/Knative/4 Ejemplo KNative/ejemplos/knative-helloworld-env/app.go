package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func handlePost(rw http.ResponseWriter, req *http.Request) {
	// Say Hello!
	from := os.Getenv("FROM")
	fmt.Fprintf(rw, "Hello from %s!", from)
	if from == "" {
		from = "Knative"
	}
}

func main() {
	log.Print("Starting server on port 8080...")
	http.HandleFunc("/", handlePost)
	log.Fatal(http.ListenAndServe(":8080", nil))
}

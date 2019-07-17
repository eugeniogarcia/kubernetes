package main

import (
	"fmt"
	"log"
	"net/http"
)

func handlePost(rw http.ResponseWriter, req *http.Request) {
	// Say Hello!
	fmt.Fprintf(rw, "Hello from port %s!", "8081")
}

func main() {
	log.Print("Starting server on port 8081...")
	http.HandleFunc("/", handlePost)
	log.Fatal(http.ListenAndServe(":8081", nil))
}

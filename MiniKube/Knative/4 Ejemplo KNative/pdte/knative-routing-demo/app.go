package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func handlePost(rw http.ResponseWriter, req *http.Request) {
	version := os.Getenv("VERSION")
	fmt.Fprintf(rw, "Hello from version %s!", version)
}

func main() {
	log.Print("Starting server on port 8080...")
	http.HandleFunc("/", handlePost)
	log.Fatal(http.ListenAndServe(":8080", nil))
}

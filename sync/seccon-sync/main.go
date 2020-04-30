package main

import (
	"os"
	"log"
	"net/http"
	
	sc "seccon-sync/go"
)

func main() {

	// set up routes
	router := sc.NewRouter()

	sc.SetUpUrls(os.Args[1:])
	
	log.Printf("Server started")
	log.Fatal(http.ListenAndServe(":8080", router))
}

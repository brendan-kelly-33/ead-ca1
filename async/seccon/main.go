package main

import (
	"os"
	"strconv"
	"log"
	"net/http"
	"time"
	
	sc "seccon/go"
)

func main() {

	// set up routes
	router := sc.NewRouter()

	// get interval parameter
	intervalMillis, err := strconv.Atoi(os.Args[2])
	if err != nil {
		panic(err)
	}

	// get wait parameter
	waitMillis, err2 := strconv.Atoi(os.Args[3])
	if err2 != nil {
		panic(err2)
	}

	// set up subscribe connection
	sc.SetUpSecConPubSub(os.Args[1], time.Duration(intervalMillis), time.Duration(waitMillis), os.Args[4:])
	
	log.Printf("Server started")
	log.Fatal(http.ListenAndServe(":8080", router))
}

package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"net/http"
	"strconv"
	"time"
)

/* Global variable to define door entry count */
var doorCount int = 0

/* Handle response */
func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, doorCount)
}

/* Main execution */
func main() {
	// get the door number from command line arg 1
	doorNum, err := strconv.Atoi(os.Args[1])
	if err != nil {
		panic(err)
	}
	doorName := "door" + strconv.Itoa(doorNum)

	// get the max number of seconds between entries for the random generator
	maxSeconds, err := strconv.Atoi(os.Args[2])
	if err != nil {
		panic(err)
	}

	// Thread to increment count
	go func() {
		log.Printf(doorName + "[INFO]: In second thread.")

		for {
			doorCount++
			log.Printf(doorName + "[INFO]: Incrementing door count: " + strconv.Itoa(doorCount))
			time.Sleep(time.Duration(rand.Intn(maxSeconds)) * time.Second)
		}
	}()

	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":8888", nil))
}

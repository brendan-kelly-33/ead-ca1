package main

import (
	"os"
	"log"
	"strconv"
	"time"
	"math/rand"
	. "github.com/mediocregopher/radix/v3"   // redis api for pub-sub
)

func main() {

	// get the door number from command line arg 1
	doorNum, err := strconv.Atoi(os.Args[1])
	if err != nil {
		panic(err)
	}

	// get the max number of seconds between entries for the random generator
	maxSeconds, err := strconv.Atoi(os.Args[2])
	if err != nil {
		panic(err)
	}

	// connect to redis specified by url in the third argument
	conn, err := Dial("tcp", os.Args[3])
	if err != nil {
		panic(err)
	}

	for {
		doorName := "door" + strconv.Itoa(doorNum)
		log.Printf(doorName + "[INFO]: Publishing to channel " + doorName)
		// the event contains a dummy string "1" - it is the count of events that matters, not the content
		conn.Do(Cmd(nil, "PUBLISH", doorName, "1"))
		time.Sleep(time.Duration(rand.Intn(maxSeconds)) * time.Second)
	}

}

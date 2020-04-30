package seccon

import (
	"log"
	"time"
	. "github.com/mediocregopher/radix/v3"   // redis api for pub-sub
)

func SetUpPubSub(serverName string, redis_url string, interval time.Duration, wait time.Duration, channel_names []string, process_func func(string, string)) {

	conn, err := Dial("tcp", redis_url)
	if err != nil {
		panic(err)
	}
	psConn := PubSub(conn)

	numChannels := len(channel_names)
	
	var channels []chan PubSubMessage = make([]chan PubSubMessage, numChannels) 
	log.Printf("")
	for i, chName := range channel_names {
		channels[i] = make(chan PubSubMessage)
		if err := psConn.Subscribe(channels[i], chName); err != nil {
			panic(err)
		} else {			
			log.Printf(serverName + "[INFO]: Subscribed to channel " + chName)
		}
	}

	// run the function that receives on the channels in a separate thread
	go func() {
		log.Printf(serverName + "[INFO]: In second thread.")
		for {
			log.Printf(serverName + "[INFO]: Polling... ")
			for index, ch := range channels {
				log.Printf(serverName + "[INFO]:        channel " + channel_names[index])
				select {
				case msg := <-ch:
					process_func(channel_names[index], string(msg.Message))
				case <-time.After(wait * time.Millisecond):
				}
   			}
			log.Printf(serverName + "[INFO]: Going to sleep for a while.")
			time.Sleep(interval * time.Millisecond)
		}
	}()
}

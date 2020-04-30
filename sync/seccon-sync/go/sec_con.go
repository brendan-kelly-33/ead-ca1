package seccon

import (
	"net/http"
	"html/template"
	"strconv"
	"log"
	"io/ioutil"
	"strings"
)

var counts map[string]int = make(map[string]int)
var urlList []string

func SetUpUrls(door_name []string) {
	urlList = door_name;
}

func GetTableInnerHTML() string {
	var innerHTML string = "<tr>"
	for _, name := range urlList {
		innerHTML += "<th>" + name + "</th>"
	}
	innerHTML += "</tr><tr>"
	for _, name := range urlList {
		innerHTML += "<th>" + strconv.Itoa(counts[name]) + "</th>"
	}
	innerHTML += "</tr>"
	return innerHTML
}

func Index(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")

	var fetchedStrings map[string]string = make(map[string]string)
	//for i := 0; i < len(urlList); i++ {
	for _, url := range urlList {
		log.Printf("seccon-sync[INFO]: Getting data from " + url)
		resp, err := http.Get("http://" + url + "-sync-service:8888")

		if (err != nil) {
			log.Printf("seccon-sync[ERROR]: Couldn't get " + url + " from site." + err.Error())
		} else {
			if resp.StatusCode == http.StatusOK {
				bodyBytes, err2 := ioutil.ReadAll(resp.Body) 
				if (err2 != nil) {
					log.Printf("seccon-sync[ERROR]: Couldn't get " + url + " from response." + err.Error())
				} else {
					return_val := string(bodyBytes)
					return_val = strings.TrimSuffix(return_val, "\n")

					log.Printf("seccon-sync[INFO]: Return value" + return_val)

					fetchedStrings[url] = return_val
				}
			} else {
				log.Printf("seccon-sync[ERROR]: HTTP returned status " + string(resp.StatusCode))
			}
		}
	}

	for i := 0; i < len(fetchedStrings); i++ {
		value, err3 := strconv.Atoi(fetchedStrings[urlList[i]])

		if (err3 != nil) {
			log.Printf("seccon-sync[ERROR]: " + err3.Error())
		} else {
			counts[urlList[i]] = value
		}
	}

	inserts := struct {
    		TableInnerHTML template.HTML	
	}{
		template.HTML(GetTableInnerHTML()),
	}
	t, _ := template.ParseFiles("console.html")
	
	t.Execute(w, inserts)
}

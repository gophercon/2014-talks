package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os/user"
)

func main() {
	u, err := user.Lookup("kelseyhightower")
	if err != nil {
		log.Fatal(err)
	}
	data, err := json.MarshalIndent(u, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("%s\n", data)
}

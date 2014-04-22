// +build ignore

// gatt_server.go is a simple demonstration GATT server.
//
// The gatt package on which this sample code depends
// did not have an API stability guarantee when this
// was written.
package main

import (
	"fmt"
	"log"
	"time"

	"github.com/paypal/gatt"
)

func main() {
	srv := &gatt.Server{Name: "GopherCon2014"}
	srv.Connect = func(c gatt.Conn) { log.Println("Connect: ", c) }
	srv.Disconnect = func(c gatt.Conn) { log.Println("Disconnect: ", c) }

	svc := srv.AddService(gatt.MustParseUUID("09fc95c0-c111-11e3-9904-0002a5d5c51b"))

	rchar := svc.AddCharacteristic(gatt.MustParseUUID("11fac9e0-c111-11e3-9246-0002a5d5c51b"))
	rchar.HandleReadFunc(
		func(resp gatt.ReadResponseWriter, req *gatt.ReadRequest) {
			tz, off := time.Now().Zone()
			fmt.Fprintf(resp, "%v (%d)", tz, off/3600) // HL
		})

	wchar := svc.AddCharacteristic(gatt.MustParseUUID("16fe0d80-c111-11e3-b8c8-0002a5d5c51b"))
	wchar.HandleWriteFunc(
		func(r gatt.Request, data []byte) (status byte) {
			log.Printf("Central wrote: %s", data) // HL
			return gatt.StatusSuccess
		})

	nchar := svc.AddCharacteristic(gatt.MustParseUUID("1c927b50-c116-11e3-8a33-0800200c9a66"))
	nchar.HandleNotifyFunc(
		func(r gatt.Request, n gatt.Notifier) {
			go func() {
				tick := 0
				for !n.Done() {
					fmt.Fprintf(n, "Tick: %d", tick) // HL
					tick++
					time.Sleep(time.Second)
				}
			}()
		})

	log.Printf("Advertising service %v", svc.UUID())
	log.Fatal(srv.AdvertiseAndServe())
}

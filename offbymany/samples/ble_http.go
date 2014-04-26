// +build ignore

// ble_http is a sample http server using BLE as a transport.
//
// It is meant to be used with the BLEBrowser OS X app in this
// same repo.
//
// The gatt package on which this sample code depends
// did not have an API stability guarantee when this
// was written.
package main

import (
	"log"
	"net/http"
	"runtime"
	"text/template"

	"github.com/gophercon/2014-talks/offbymany/blenet"
	"github.com/paypal/gatt"
)

func main() {
	serviceUUID := gatt.MustParseUUID("39170DC9-E537-43B0-AE6E-F7D2DE3031E0")
	writeUUID := gatt.MustParseUUID("275E9963-D7E4-47A5-B43A-8BFC360F5032")
	notifyUUID := gatt.MustParseUUID("77500CA7-CD0D-4FFE-88CD-07A3E8F509A5")
	bleListener := blenet.NewListener(serviceUUID, writeUUID, notifyUUID)

	page := `<html><body>  Hi! I am a <strong>{{.Os}}/{{.Arch}}</strong> system.  </body></html>`
	tpl := template.Must(template.New("home").Parse(page))

	http.HandleFunc("/", func(resp http.ResponseWriter, req *http.Request) {
		sys := struct {
			Os   string
			Arch string
		}{
			Os:   runtime.GOOS,
			Arch: runtime.GOARCH,
		}
		tpl.Execute(resp, sys)
	})

	s := new(http.Server)
	log.Fatal(s.Serve(bleListener))
}

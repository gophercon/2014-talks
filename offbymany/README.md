These are the slides and sample code for the talk "Bluetooth Low Energy and Embedded Go", by [Josh Bleecher Snyder](https://twitter.com/offbymany).

Use [present](https://godoc.org/code.google.com/p/go.talks/present) to view [the slides](./ble_embedded.slide).

The `samples` directory contains two executable code samples. The main sample referenced in the talk is [gatt_server.go](./samples/gatt_server.go).

The `blenet` package contains a package for creating a [net.Conn](http://golang.org/pkg/net/#Conn) and a [net.Listener](http://golang.org/pkg/net/#Listener) out of a [gatt server](https://github.com/paypal/gatt).

The `BLEBrowser` directory contains an OS X app that dials a `blenet` peripheral and displays the results in a webview. See the [README](./BLEBrowser/README.md) for more details. Try it out with the [ble_http.go](./samples/ble_http.go) sample executable.

None of the code here is ready for production use. It is intended only for demonstration and learning purposes; there is a shortage of functional BLE sample code on the web.

All code in this directory and subdirectories is released under a [BSD-style license](./LICENSE.md).

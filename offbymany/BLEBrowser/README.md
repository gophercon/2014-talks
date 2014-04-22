BLEBrowser is a simplistic OS X app that dials a `blenet` peripheral and displays the results in a webview. It is meant to be used with [ble_http.go](../samples/ble_http.go) or another command written using the [blenet package](../blenet) in this repo. The techniques and code used here can be adapted straightforwardly to iOS.

It is strongly recommended that you turn off wifi before running BLEBrowser. The wifi chip will shut down the BLE chip intermittently, which wreaks havoc on the slow process of transferring data.

The high level picture is as follows:

* The application delegate registers a [custom NSURLProtocol](http://nshipster.com/nsurlprotocol/) to handle BLE url requests, sets up a webview, starts the BLE machinery (BBConnection) in motion, creates a request, associates the request with BLE, and sends the request.

* BBConnection is scanning for peripherals. If it finds one advertising the right service UUID, it connects, and looks for characteristics with the right UUIDs. Once both characteristics have been found, and the notification characteristic is notifying, the connection is ready to send and receive data.

* BBURLProtocol, meanwhile, waits until all other requests have cleared. This is because, in our simplistic model, there is no muxing, so requests must be sent one at a time. Once we are free to send the request, BBURLProtocol serializes the request using the HTTP wire protocol, and requests the connection to send that data. 

* The connection writes the request and dispatches reply packets as they arrive to the protocol handler. The protocol handler constructs an HTTP reply from them, handling Content-Length and chunked transfer encoding as needed. It notifies its delegate as data becomes available. The NSURLConnection network stack in turn passes the response to the webview, which renders it and possibly triggers new requests.

* New requests are intercepted by the application delegate, associated with the same BLE connection (there can be only one at a time), given a nice long timeout to deal with the excruciatingly low bandwidth, and dispatched by the URL loading system.

BLEBrowser uses code from [TouchHTTPD](https://github.com/TouchCode/TouchHTTPD), with thanks.

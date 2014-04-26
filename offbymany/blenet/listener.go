package blenet

import (
	"errors"
	"log"
	"net"
	"sync"

	"github.com/paypal/gatt"
)

// Listener is a net.Listener for BLE connections.
type Listener struct {
	addr  net.Addr
	conn  *conn // the active connection
	connc chan net.Conn

	startonce sync.Once
	srv       *gatt.Server
	errc      chan error // errors encountered during serving

	closeonce sync.Once
}

// Accept waits for and returns the next connection to the listener.
func (l *Listener) Accept() (net.Conn, error) {
	l.startonce.Do(func() {
		l.errc = make(chan error)
		go func() {
			l.errc <- l.srv.AdvertiseAndServe()
		}()
	})
	select {
	case c, ok := <-l.connc:
		if !ok {
			return nil, errors.New("listener is closed")
		}
		l.conn = c.(*conn)
		return c, nil
	case err := <-l.errc:
		l.Close()
		return nil, err
	}
}

// Close closes the listener.
// Any blocked Accept operations will be unblocked and return errors.
func (l *Listener) Close() error {
	l.closeonce.Do(func() {
		close(l.connc)
		close(l.errc)
		l.srv.Close()
	})
	return nil
}

// Addr returns the listener's network address.
func (l *Listener) Addr() net.Addr {
	return l.addr
}

func (l *Listener) connect(gattconn gatt.Conn) {
	log.Println("New connection from", gattconn.RemoteAddr())
	defer func() { recover() }() // don't panic if l.connc is closed
	l.addr = gattconn.LocalAddr()
	l.connc <- newConn(gattconn)
}

func (l *Listener) disconnect(gattconn gatt.Conn) {
	log.Println("Disconnected:", gattconn.RemoteAddr())
	if gattconn.RemoteAddr().String() == l.conn.gattconn.RemoteAddr().String() {
		l.conn.Close()
	}
	l.conn = nil
}

// ServeWrite handles write requests by passing them
// through to the active connection.
func (l *Listener) ServeWrite(r gatt.Request, data []byte) byte {
	if r.Conn == l.conn.gattconn {
		l.conn.Receive(data)
	}
	return gatt.StatusSuccess
}

// ServeNotify handles write requests by passing them
// through to the active connection.
func (l *Listener) ServeNotify(r gatt.Request, n gatt.Notifier) {
	if r.Conn == l.conn.gattconn {
		l.conn.Notify(n)
	}
}

func NewListener(svcUUID, writeUUID, notifyUUID gatt.UUID) *Listener {
	l := &Listener{
		connc: make(chan net.Conn),
	}

	l.srv = &gatt.Server{
		Connect:    l.connect,
		Disconnect: l.disconnect,
		Name:       "blenet",
	}
	svc := l.srv.AddService(svcUUID)
	wchar := svc.AddCharacteristic(writeUUID)
	wchar.HandleWrite(l)
	nchar := svc.AddCharacteristic(notifyUUID)
	nchar.HandleNotify(l)

	return l
}

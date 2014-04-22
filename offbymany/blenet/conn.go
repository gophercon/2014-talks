package blenet

import (
	"errors"
	"io"
	"net"
	"sync"
	"time"

	"github.com/paypal/gatt"
)

// conn is a net.Conn for BLE connections.
type conn struct {
	gattconn gatt.Conn

	readc     chan []byte
	readbufmu sync.Mutex
	readbuf   []byte // used to hold a single read received from readc but not yet handled via Read

	writec    chan *writereq
	closeonce sync.Once
}

type writereq struct {
	b      []byte
	replyc chan error
}

func newConn(gattconn gatt.Conn) net.Conn {
	return &conn{
		gattconn: gattconn,
		readc:    make(chan []byte),
		writec:   make(chan *writereq),
	}
}

// Receive informs the connection that new data
// has been received and is ready to be read.
func (c *conn) Receive(b []byte) {
	defer func() { recover() }() // don't panic if c.readc is closed
	c.readc <- b
}

// Read reads data from the connection.
func (c *conn) Read(b []byte) (int, error) {
	c.readbufmu.Lock()
	defer c.readbufmu.Unlock()
	if c.readbuf == nil {
		data, ok := <-c.readc
		if !ok {
			return 0, io.ErrClosedPipe
		}
		c.readbuf = data
	}
	if len(c.readbuf) > len(b) {
		return 0, io.ErrShortBuffer
	}

	n := copy(b, c.readbuf)
	c.readbuf = nil
	// log.Printf("Read: %s", b[:n])
	return n, nil
}

// Write writes data to the connection.
func (c *conn) Write(b []byte) (n int, err error) {
	// log.Printf("Write: %s", b)
	defer func() {
		if err := recover(); err != nil {
			// writec is closed
			n, err = 0, io.ErrClosedPipe
		}
	}()

	req := &writereq{b: b, replyc: make(chan error, 1)}
	c.writec <- req
	err = <-req.replyc
	if err != nil {
		return 0, err
	}
	return len(b), nil
}

// Close closes the connection.
// Any blocked Read or Write operations will be unblocked and return errors.
func (c *conn) Close() error {
	c.closeonce.Do(func() {
		close(c.readc)
		close(c.writec)
	})
	return nil
}

func (c *conn) Notify(n gatt.Notifier) {
	go func() {
		for {
			req, ok := <-c.writec
			if !ok {
				// writec has been closed.
				// Close the corresponding underlying connection here.
				c.gattconn.Close()
				return
			}
			if n.Done() {
				req.replyc <- io.ErrClosedPipe
				c.Close()
				return
			}
			data := req.b
			// Send out data, one packet at a time
			for len(data) > 0 {
				l := len(data)
				if c := n.Cap(); l > c {
					l = c
				}
				if _, err := n.Write(data[:l]); err != nil {
					req.replyc <- err
					c.Close()
					return
				}
				data = data[l:]
			}
			req.replyc <- nil
		}
	}()
}

func (c *conn) LocalAddr() net.Addr                { return c.gattconn.LocalAddr() }
func (c *conn) RemoteAddr() net.Addr               { return c.gattconn.RemoteAddr() }
func (c *conn) SetDeadline(t time.Time) error      { return errors.New("not implemented") }
func (c *conn) SetReadDeadline(t time.Time) error  { return errors.New("not implemented") }
func (c *conn) SetWriteDeadline(t time.Time) error { return errors.New("not implemented") }

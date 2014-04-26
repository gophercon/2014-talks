// START TOOLCHAIN OMIT
cd /usr/local/go/src

for os in linux windows darwin; do
  GOOS=${os} GOARCH=amd64 ./make.bash —no-clean
done
// END TOOLCHAIN OMIT

// START BUILD OMIT
GOOS=linux go build -o ipxeserver .
// END BUILD OMIT

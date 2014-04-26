// This runs my (Brad Fitzpatrick) presentation from Gophercon 2014:
// Camlistore & the Standard Library.
//
// It depends on shellinabox and docker. I was using boot2docker too,
// so it might accidentally assume that in places, particularly in
// the shell port forwarding handler.
//
// Sorry for lack of comments. This was a frantic hack before my
// presentation.
//
// Maybe I'll clean this up and put it elsewhere later.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

var (
	dockerFlag = flag.String("docker", "", "Path to docker, for child process")
	listenFlag = flag.String("listen", "127.0.0.1:3998", "Listen address")
	tagFlag    = flag.String("tag", "", "If non-empty, we're the child process and we should start or attach to this gc14:<tag> VM.")
)

var presentURL = httputil.NewSingleHostReverseProxy(&url.URL{
	Scheme: "http",
	Host:   "127.0.0.1:3999",
	Path:   "/",
})

var talkDir string

func handleRoot(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	if path == "/" || strings.HasSuffix(path, ".slide") ||
		strings.HasPrefix(path, "/static/") ||
		strings.HasSuffix(path, ".png") {
		presentURL.ServeHTTP(w, r)
		return
	}
	http.NotFound(w, r)
}

type Shell struct {
	p     *os.Process
	port  int
	proxy http.Handler
}

var (
	mu    sync.Mutex
	shell = map[string]*Shell{}
)

var shellPortRx = regexp.MustCompile(`^/shell/(\S+?)/(\d{2,5})\b`)

func handleShell(w http.ResponseWriter, r *http.Request) {
	if m := shellPortRx.FindStringSubmatch(r.URL.Path); m != nil {
		port, _ := strconv.Atoi(m[2])
		handleShellPort(w, r, m[1], port)
		return
	}
	name := strings.TrimPrefix(r.URL.Path, "/shell/")
	if i := strings.Index(name, "/"); i >= 0 {
		name = name[:i]
	}
	mu.Lock()
	p, ok := shell[name]
	mu.Unlock()
	if ok {
		p.proxy.ServeHTTP(w, r)
		return
	}
	groupsb, err := exec.Command("groups").Output()
	if err != nil {
		log.Fatal(err)
	}
	groups := strings.Fields(string(groupsb))

	dockerPath, _ := exec.LookPath("docker")

	program := "/bin/bash"
	if name != "local" {
		script := fmt.Sprintf(`#!/bin/sh
export DOCKER_HOST=%s
%s --tag=%s --docker=%s
`, os.Getenv("DOCKER_HOST"), os.Args[0], name, dockerPath)
		f, err := ioutil.TempFile("", "")
		if err != nil {
			log.Fatalf("TempFile: %v", err)
		}
		f.Write([]byte(script))
		f.Close()
		os.Chmod(f.Name(), 0770)
		program = f.Name()
	}

	u, err := user.Current()
	if err != nil {
		log.Fatal(err)
	}
	port := freePort()
	args := []string{
		"--no-beep",
		"--disable-ssl",
		fmt.Sprintf("--port=%d", port),
		fmt.Sprintf("--service=/shell/%s:%s:%s:%s:%s", name, u.Username, groups[0], u.HomeDir, program),
	}
	css := filepath.Join(talkDir, "shell.css")
	if _, err := os.Stat(css); err == nil {
		args = append(args, "--css="+css)
	}
	cmd := exec.Command("shellinaboxd", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	proxy := httputil.NewSingleHostReverseProxy(&url.URL{
		Scheme: "http",
		Host:   "127.0.0.1:" + strconv.Itoa(port),
		Path:   "/",
	})
	mu.Lock()
	shell[name] = &Shell{
		p:     cmd.Process,
		port:  port,
		proxy: proxy,
	}
	mu.Unlock()
	go func() {
		err := cmd.Wait()
		log.Printf("Image %s ended with: %v", name, err)
		mu.Lock()
		defer mu.Unlock()
		delete(shell, name)
	}()
	time.Sleep(150 * time.Millisecond) // warm up time
	proxy.ServeHTTP(w, r)
}

func handleShellPort(w http.ResponseWriter, r *http.Request, tag string, port int) {
	outb, err := exec.Command("docker", "ps", "--no-trunc").CombinedOutput()
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	sc := bufio.NewScanner(bytes.NewReader(outb))
	img := "gc14:" + tag
	var containers []string
	for sc.Scan() {
		if strings.Contains(sc.Text(), img) {
			fields := strings.Fields(sc.Text())
			containers = append(containers, fields[0])
		}
	}
	if len(containers) == 0 {
		http.NotFound(w, r)
		return
	}
	ip, err := IP(containers[0])
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	localPort := freePort()
	cmd := exec.Command("ssh",
		"-i", filepath.Join(os.Getenv("HOME"), ".ssh", "id_rsa_boot2docker"),
		"-o", "StrictHostKeyChecking=no",
		"-o", "ExitOnForwardFailure=yes",
		"-o", "UserKnownHostsFile=/dev/null",
		"-p", "2022",
		"docker@localhost",
		fmt.Sprintf("-L%d:%s:%d", localPort, ip, port),
		"-N")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	go func() {
		if err := cmd.Wait(); err != nil {
			log.Printf("ssh port forward ended for %s: %v", tag, err)
		}
	}()
	time.Sleep(100 * time.Millisecond)
	http.Redirect(w, r, fmt.Sprintf("http://127.0.0.1:%d", localPort), http.StatusFound)
}

func freePort() int {
	for p := 3900; p < 4200; p++ {
		c, err := net.Dial("tcp", "localhost:"+strconv.Itoa(p))
		if err != nil {
			return p
		}
		c.Close()
	}
	panic("out of ports?")
}

func main() {
	flag.Parse()
	if *dockerFlag == "" {
		if err := exec.Command("docker", "ps").Run(); err != nil {
			os.Setenv("DOCKER_HOST", "tcp://localhost:4243")
			if err := exec.Command("docker", "ps").Run(); err != nil {
				log.Fatalf("Failed to run docker ps. Forget boot2docker up?")
			}
		}
		*dockerFlag = "docker"
	}
	if *tagFlag != "" {
		startAttachTag(*tagFlag)
		return
	}
	verifyEnvironment()
	http.HandleFunc("/shell/", handleShell)
	http.Handle("/img/", http.FileServer(http.Dir(talkDir)))
	http.HandleFunc("/", handleRoot)

	log.Printf("Presenting to Gophercon 2014 on http://%s", *listenFlag)
	go exec.Command("open", "http://"+*listenFlag+"/2014-04-Gophercon.slide#1").Start()
	log.Fatal(http.ListenAndServe(*listenFlag, nil))
}

func verifyEnvironment() {
	var err error
	talkDir, err = os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(talkDir, "2014-04-Gophercon.slide")); err != nil {
		if os.IsNotExist(err) {
			log.Fatalf("Failed to find 2014-04-Gophercon.slide in directory %s", talkDir)
		}
		log.Fatal(err)
	}

	images, err := exec.Command("docker", "images").Output()
	if err != nil {
		log.Fatal(err)
	}
	testHaveImage(images, "gc14", "earlygo")
	testHaveImage(images, "gc14", "earlycam")
	testHaveImage(images, "gc14", "cam")

	foreachDockerPs(func(image, containerID string) {
		go func() {
			log.Printf("Killing existing %s: %s", image, containerID)
			exec.Command(*dockerFlag, "kill", containerID).Run()
			exec.Command(*dockerFlag, "rm", containerID).Run()
		}()
	})

	if _, err := exec.LookPath("shellinaboxd"); err != nil {
		log.Fatalf("Can't find shellinaboxd in path")
	}

	exec.Command("killall", "present").Run()
	exec.Command("killall", "shellinabox").Run()
	presentCmd := exec.Command("present", ".")
	presentCmd.Dir = talkDir
	if err := presentCmd.Start(); err != nil {
		log.Fatalf("Error starting present: %v", err)
	}
}

func testHaveImage(images []byte, repo, tag string) {
	rx := regexp.MustCompile(`(?m)^` + repo + `\b\s+\b` + tag + `\b`)
	if !rx.Match(images) {
		log.Fatalf("Didn't find required Docker image %s:%s; forget to build it? See child directory %q and run `make build`",
			repo, tag, tag)
	}
}

func foreachDockerPs(fn func(image, containerID string)) {
	outb, err := exec.Command(*dockerFlag, "ps", "--no-trunc").CombinedOutput()
	if err != nil {
		log.Fatalf("docker ps: %v: %s", err, outb)
	}
	sc := bufio.NewScanner(bytes.NewReader(outb))
	for sc.Scan() {
		t := sc.Text()
		if !strings.Contains(t, "gc14:") {
			continue
		}
		f := strings.Fields(t)
		fn(f[1], f[0])
	}
}

func startAttachTag(tag string) {
	if *dockerFlag == "" {
		*dockerFlag, _ = exec.LookPath("docker")
	}
	var containers []string
	img := "gc14:" + tag
	foreachDockerPs(func(runningImage, containerID string) {
		if runningImage != img {
			return
		}
		containers = append(containers, containerID)
	})
	switch {
	case len(containers) > 1:
		for _, container := range containers {
			// Best effort:
			exec.Command(*dockerFlag, "kill", container).Run()
			exec.Command(*dockerFlag, "rm", container).Run()
		}
	case len(containers) == 1:
		if err := syscall.Exec(*dockerFlag,
			[]string{*dockerFlag, "attach", containers[0]},
			os.Environ()); err != nil {
			log.Fatalf("docker attach exec: %v", err)
		}
	}
	if err := syscall.Exec(*dockerFlag,
		[]string{*dockerFlag, "run", "-t", "-i", "-h", tag, "-w", "/home/gopher", img, "/bin/bash"},
		os.Environ()); err != nil {
		log.Fatalf("docker run exec: %v", err)
	}
}

// IP returns the IP address of the container.
func IP(containerID string) (string, error) {
	out, err := exec.Command("docker", "inspect", containerID).Output()
	if err != nil {
		return "", err
	}
	type networkSettings struct {
		IPAddress string
	}
	type container struct {
		NetworkSettings networkSettings
	}
	var c []container
	if err := json.NewDecoder(bytes.NewReader(out)).Decode(&c); err != nil {
		return "", err
	}
	if len(c) == 0 {
		return "", errors.New("no output from docker inspect")
	}
	if ip := c[0].NetworkSettings.IPAddress; ip != "" {
		return ip, nil
	}
	return "", fmt.Errorf("could not find an IP for %v. Not running?", containerID)
}

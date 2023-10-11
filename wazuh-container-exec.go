package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strconv"
	"sync"
	"time"
)

const EOF = 0

var listenPath = getEnvOrDef("WAZUH_AGENT_CONTAINER_EXEC_LISTEN_PATH", path.Join(os.Getenv("WAZUH_AGENT_HOST_DIR"), "/var/ossec/container-exec.sock"))
var connectPath = getEnvOrDef("WAZUH_AGENT_CONTAINER_EXEC_CONNECT_PATH", "/var/ossec/container-exec.sock")
var logFile = getEnvOrDef("WAZUH_AGENT_CONTAINER_EXEC_LOG_FILE", "/var/ossec/logs/active-responses.log")

func getEnvOrDef(name, def string) string {
	v, ok := os.LookupEnv(name)
	if !ok {
		return def
	}
	return v
}

func client() {
	conn, err := net.Dial("unix", connectPath)
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	stdout := os.Stdout
	if logFile != "" {
		stdout, err = os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			panic(err)
		}
		defer stdout.Close()
	}

	go func() {
		if _, err := io.Copy(conn, os.Stdin); err != nil {
			fmt.Fprintln(stdout, "Error copying to stdin: ", err)
			return
		}
		if _, err := conn.Write([]byte{EOF, '\n'}); err != nil {
			fmt.Fprintln(stdout, "Error sending EOF: ", err)
			return
		}
	}()

	if _, err := io.Copy(stdout, conn); err != nil {
		fmt.Fprintln(stdout, "Error copying to stdout: ", err)
		os.Exit(1)
	}
}

type syslogWrapper struct {
	hostname string
	cmd      *exec.Cmd
	name     string
	w        io.Writer
}

func newSyslogWrapper(cmd *exec.Cmd, w io.Writer) io.Writer {
	h, err := os.Hostname()
	if err != nil {
		h = "unknown"
	}
	return syslogWrapper{
		hostname: h,
		cmd:      cmd,
		name:     filepath.Base(cmd.Path),
		w:        w,
	}
}

func (l syslogWrapper) Write(p []byte) (n int, err error) {
	h := time.Now().Format(time.Stamp) + " " +
		l.hostname + " " +
		l.name + "[" + strconv.Itoa(l.cmd.Process.Pid) + "]" +
		": "
	n, err = l.w.Write(append([]byte(h), p...))
	if n = n - len(h); n < 0 {
		n = 0
	}
	return
}

type activeResponseData struct {
	Parameters struct {
		ExtraArgs []string `json:"extra_args"`
	} `json:"parameters"`
}

func server() {
	listener, err := net.Listen("unix", listenPath)
	if err != nil {
		panic(err)
	}
	defer listener.Close()

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Println("Error accepting connection:", err)
			continue
		}

		go func(conn net.Conn) {
			defer conn.Close()
			done := false

			r := bufio.NewReader(conn)
			line, err := r.ReadBytes('\n')
			if err != nil {
				conn.Write([]byte(err.Error()))
				return
			}

			var args []string
			ard := &activeResponseData{}
			if err := json.Unmarshal(line, ard); err == nil {
				args = ard.Parameters.ExtraArgs
				if len(args) == 0 {
					conn.Write([]byte("No arguments specified"))
					return
				}

			} else {
				ard = nil
				args = []string{"bash"}
			}

			cmd := exec.Command(args[0], args[1:]...)
			var writter io.Writer = conn
			if ard != nil {
				writter = newSyslogWrapper(cmd, conn)
			}
			stdin, err := cmd.StdinPipe()
			if err != nil {
				conn.Write([]byte(err.Error()))
				log.Println("Error getting stdin pipe:", err)
				return
			}
			stdout, err := cmd.StdoutPipe()
			if err != nil {
				conn.Write([]byte(err.Error()))
				log.Println("Error getting stdout pipe:", err)
				return
			}
			stderr, err := cmd.StderrPipe()
			if err != nil {
				conn.Write([]byte(err.Error()))
				log.Println("Error getting stderr pipe:", err)
				return
			}

			var wg sync.WaitGroup
			wg.Add(3)
			defer wg.Wait()
			go func() {
				defer wg.Done()
				defer stdin.Close()
				for len(line) > 1 && !(len(line) == 2 && line[0] == EOF) {
					_, err := io.WriteString(stdin, string(line))
					if err != nil {
						conn.Write([]byte(err.Error()))
						log.Println("Error writing to stdin:", err)
						return
					}

					line, err = r.ReadBytes('\n')
					if err != nil && !errors.Is(err, io.EOF) && !done {
						log.Println("Error reading from connection:", err)
					}
					if err != nil {
						cmd.Process.Kill()
					}
				}
			}()
			go func() {
				defer wg.Done()
				defer stdout.Close()
				if _, err := io.Copy(writter, stdout); err != nil && !done {
					log.Println("Error copying stdout:", err)
				}
			}()
			go func() {
				defer wg.Done()
				defer stderr.Close()
				if _, err := io.Copy(writter, stderr); err != nil && !done {
					log.Println("Error copying stderr:", err)
				}
			}()

			defer conn.Close()
			if err := cmd.Run(); err != nil {
				conn.Write([]byte(err.Error()))
				log.Println("Error executing command:", err)
			}
			done = true
		}(conn)
	}
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "server" {
		server()
		return
	}

	client()
}

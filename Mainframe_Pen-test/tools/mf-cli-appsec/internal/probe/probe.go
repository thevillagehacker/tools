package probe

import (
	"fmt"
	"net"
	"os/exec"
	"time"
)

type Result struct {
	Status string
	Detail string
}

func TCP(host string, port int, timeout time.Duration) Result {
	addr := fmt.Sprintf("%s:%d", host, port)
	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		return Result{Status: "CLOSED/FILTERED", Detail: err.Error()}
	}
	_ = conn.Close()
	return Result{Status: "OPEN", Detail: "tcp connect ok"}
}

func S3270(host string, port int, timeout time.Duration) Result {
	path, err := exec.LookPath("s3270")
	if err != nil {
		return Result{Status: "SKIP", Detail: "s3270 not found on PATH"}
	}
	// Minimal: just ensure binary exists; full connect is via runner.
	_ = path
	_ = host
	_ = port
	_ = timeout
	return Result{Status: "READY", Detail: "s3270 binary found — use 'run' for full connect"}
}

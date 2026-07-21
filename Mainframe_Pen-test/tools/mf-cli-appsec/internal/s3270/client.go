// Package s3270 drives the headless x3270-family emulator (s3270) via its
// peer-script protocol (stdin commands / stdout responses).
//
// Protocol reference: https://x3270.bgp.nu/Unix/x3270-script.html
//
// Every action completes with:
//  1. zero or more lines:  data: <payload>
//  2. one status line:     12 blank-separated fields
//  3. one result line:     ok   OR   error
//
// On Windows the binary is typically s3270.exe from the wc3270/x3270 install.
package s3270

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
)

// Status is the 12-field emulator status line returned after each action.
type Status struct {
	Raw            string
	Keyboard       string // U unlocked | L locked | E operator error
	Formatted      string // F formatted | U unformatted/NVT
	FieldProtect   string // P protected | U unprotected
	Connection     string // C(host) | N
	Mode           string // I 3270 | L NVT line | C NVT char | P unnegotiated | N
	Model          string
	Rows           string
	Cols           string
	CursorRow      string
	CursorCol      string
	WindowID       string
	ExecTime       string
	Connected      bool
	KeyboardLocked bool
}

// Client is a running s3270 child process.
type Client struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout *bufio.Reader
	mu     sync.Mutex
	path   string
	// LastStatus is updated after every successful Run.
	LastStatus Status
	// CommandTimeout bounds how long we wait for ok/error (0 = no limit).
	CommandTimeout time.Duration
}

// ResolvePath finds s3270 on PATH or common Windows install locations.
func ResolvePath(explicit string) string {
	if explicit != "" && explicit != "s3270" {
		return explicit
	}
	candidates := []string{"s3270"}
	if runtime.GOOS == "windows" {
		candidates = []string{
			"s3270.exe",
			"s3270",
			filepath.Join(os.Getenv("ProgramFiles"), "wc3270", "s3270.exe"),
			filepath.Join(os.Getenv("ProgramFiles"), "x3270", "s3270.exe"),
			filepath.Join(os.Getenv("ProgramFiles(x86)"), "wc3270", "s3270.exe"),
			filepath.Join(os.Getenv("ProgramFiles(x86)"), "x3270", "s3270.exe"),
			filepath.Join(os.Getenv("LOCALAPPDATA"), "wc3270", "s3270.exe"),
		}
	}
	for _, c := range candidates {
		if c == "s3270" || c == "s3270.exe" {
			if p, err := exec.LookPath(c); err == nil {
				return p
			}
			continue
		}
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			return c
		}
	}
	if runtime.GOOS == "windows" {
		return "s3270.exe"
	}
	return "s3270"
}

// Start launches s3270 as a peer-script child.
func Start(s3270Path string) (*Client, error) {
	path := ResolvePath(s3270Path)
	cmd := exec.Command(path)
	// Ensure no unexpected locale issues on Windows console hosts.
	cmd.Env = append(os.Environ(), "LC_ALL=C")

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		_ = stdin.Close()
		return nil, err
	}
	// Discard stderr noise (traces) unless debugging — still start process.
	cmd.Stderr = nil

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start s3270 (%s): %w\nHint: install wc3270/x3270 from https://x3270.bgp.nu/ and ensure s3270.exe is on PATH", path, err)
	}

	return &Client{
		cmd:            cmd,
		stdin:          stdin,
		stdout:         bufio.NewReaderSize(stdoutPipe, 64*1024),
		path:           path,
		CommandTimeout: 120 * time.Second,
	}, nil
}

// Path returns the resolved s3270 binary path.
func (c *Client) Path() string { return c.path }

// Close sends Quit and waits for process exit.
func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.cmd == nil || c.cmd.Process == nil {
		return nil
	}
	_, _ = io.WriteString(c.stdin, "Quit\n")
	_ = c.stdin.Close()

	done := make(chan error, 1)
	go func() { done <- c.cmd.Wait() }()
	select {
	case err := <-done:
		return err
	case <-time.After(5 * time.Second):
		_ = c.cmd.Process.Kill()
		return fmt.Errorf("s3270 did not exit; killed")
	}
}

// Run sends one action and waits for the status + ok/error trailer.
func (c *Client) Run(command string) (data []string, st Status, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	command = strings.TrimSpace(command)
	if command == "" {
		return nil, Status{}, fmt.Errorf("empty s3270 command")
	}
	if !strings.HasSuffix(command, "\n") {
		command += "\n"
	}

	if _, err = io.WriteString(c.stdin, command); err != nil {
		return nil, Status{}, fmt.Errorf("write to s3270: %w", err)
	}

	type result struct {
		data []string
		st   Status
		err  error
	}
	ch := make(chan result, 1)
	go func() {
		d, s, e := c.readResponse()
		ch <- result{d, s, e}
	}()

	timeout := c.CommandTimeout
	if timeout <= 0 {
		timeout = 24 * time.Hour
	}
	select {
	case r := <-ch:
		if r.err == nil {
			c.LastStatus = r.st
		}
		return r.data, r.st, r.err
	case <-time.After(timeout):
		return nil, Status{}, fmt.Errorf("timeout after %s waiting for s3270 response to %q", timeout, strings.TrimSpace(command))
	}
}

func (c *Client) readResponse() ([]string, Status, error) {
	var (
		data       []string
		statusLine string
		st         Status
	)
	for {
		line, err := c.stdout.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				return data, st, fmt.Errorf("s3270 closed stdout unexpectedly (EOF)")
			}
			return data, st, err
		}
		line = strings.TrimRight(line, "\r\n")

		switch {
		case strings.HasPrefix(line, "data:"):
			// "data: payload" or "data:payload"
			payload := strings.TrimPrefix(line, "data:")
			if strings.HasPrefix(payload, " ") {
				payload = payload[1:]
			}
			data = append(data, payload)

		case line == "ok":
			st = parseStatus(statusLine)
			st.Raw = statusLine
			return data, st, nil

		case line == "error" || strings.HasPrefix(line, "error "):
			st = parseStatus(statusLine)
			st.Raw = statusLine
			msg := strings.Join(data, "\n")
			if msg == "" {
				msg = line
			}
			return data, st, fmt.Errorf("s3270 error: %s", msg)

		default:
			// Status line (12 fields) — keep last non-data line before ok/error.
			// Also capture unexpected diagnostic text as data for debugging.
			if looksLikeStatus(line) {
				statusLine = line
			} else if line != "" {
				// Some builds emit bare screen lines; treat as data.
				data = append(data, line)
			}
		}
	}
}

func looksLikeStatus(line string) bool {
	// Keyboard state is first field: U, L, or E
	if len(line) < 3 {
		return false
	}
	fields := strings.Fields(line)
	if len(fields) < 12 {
		// Allow slightly short lines from older builds (still treat as status if starts right).
		if len(fields) >= 5 {
			switch fields[0] {
			case "U", "L", "E":
				return true
			}
		}
		return false
	}
	switch fields[0] {
	case "U", "L", "E":
		return true
	default:
		return false
	}
}

func parseStatus(line string) Status {
	st := Status{Raw: line}
	f := strings.Fields(line)
	if len(f) > 0 {
		st.Keyboard = f[0]
		st.KeyboardLocked = f[0] != "U"
	}
	if len(f) > 1 {
		st.Formatted = f[1]
	}
	if len(f) > 2 {
		st.FieldProtect = f[2]
	}
	if len(f) > 3 {
		st.Connection = f[3]
		st.Connected = strings.HasPrefix(f[3], "C(")
	}
	if len(f) > 4 {
		st.Mode = f[4]
	}
	if len(f) > 5 {
		st.Model = f[5]
	}
	if len(f) > 6 {
		st.Rows = f[6]
	}
	if len(f) > 7 {
		st.Cols = f[7]
	}
	if len(f) > 8 {
		st.CursorRow = f[8]
	}
	if len(f) > 9 {
		st.CursorCol = f[9]
	}
	if len(f) > 10 {
		st.WindowID = f[10]
	}
	if len(f) > 11 {
		st.ExecTime = f[11]
	}
	return st
}

// --- High-level actions ---

func (c *Client) Connect(host string, port int) error {
	target := host
	if port > 0 && !strings.Contains(host, ":") {
		target = fmt.Sprintf("%s:%d", host, port)
	}
	// L: prefix = SSL tunnel (port 992 style). Caller may pass host already prefixed.
	_, _, err := c.Run(fmt.Sprintf("Connect(%s)", target))
	return err
}

// ConnectSSL uses L: prefix for SSL/TLS tunnel to host:port.
func (c *Client) ConnectSSL(host string, port int) error {
	target := fmt.Sprintf("L:%s:%d", host, port)
	_, _, err := c.Run(fmt.Sprintf("Connect(%s)", target))
	return err
}

func (c *Client) String(text string) error {
	esc := escapeStringArg(text)
	_, _, err := c.Run(fmt.Sprintf("String(%s)", esc))
	return err
}

func escapeStringArg(text string) string {
	// x3270 String() takes a double-quoted argument with C-ish escapes.
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range text {
		switch r {
		case '\\':
			b.WriteString(`\\`)
		case '"':
			b.WriteString(`\"`)
		case '\n':
			// \n in String means Enter AID — usually unwanted when typing fields.
			b.WriteString(`\n`)
		case '\t':
			b.WriteString(`\t`)
		default:
			if r < 32 {
				b.WriteString(fmt.Sprintf(`\x%02x`, r))
			} else {
				b.WriteRune(r)
			}
		}
	}
	b.WriteByte('"')
	return b.String()
}

func (c *Client) Enter() error {
	_, _, err := c.Run("Enter")
	return err
}

func (c *Client) PF(n int) error {
	if n < 1 || n > 24 {
		return fmt.Errorf("PF key must be 1-24, got %d", n)
	}
	_, _, err := c.Run(fmt.Sprintf("PF(%d)", n))
	return err
}

func (c *Client) PA(n int) error {
	if n < 1 || n > 3 {
		return fmt.Errorf("PA key must be 1-3, got %d", n)
	}
	_, _, err := c.Run(fmt.Sprintf("PA(%d)", n))
	return err
}

func (c *Client) Clear() error {
	_, _, err := c.Run("Clear")
	return err
}

func (c *Client) Tab() error {
	_, _, err := c.Run("Tab")
	return err
}

func (c *Client) BackTab() error {
	_, _, err := c.Run("BackTab")
	return err
}

func (c *Client) EraseEOF() error {
	_, _, err := c.Run("EraseEOF")
	return err
}

func (c *Client) Home() error {
	_, _, err := c.Run("Home")
	return err
}

// MoveCursor moves to zero-origin row,col (script coordinates).
func (c *Client) MoveCursor(row, col int) error {
	_, _, err := c.Run(fmt.Sprintf("MoveCursor(%d,%d)", row, col))
	return err
}

func (c *Client) Wait(mode string) error {
	if mode == "" {
		mode = "InputField"
	}
	// Optional timeout form: Wait(30,InputField) — use default action with mode only.
	_, _, err := c.Run(fmt.Sprintf("Wait(%s)", mode))
	return err
}

// WaitTimeout waits with an explicit second timeout (s3270: Wait(n,Mode)).
func (c *Client) WaitTimeout(seconds int, mode string) error {
	if mode == "" {
		mode = "InputField"
	}
	_, _, err := c.Run(fmt.Sprintf("Wait(%d,%s)", seconds, mode))
	return err
}

func (c *Client) Ascii() (string, error) {
	data, _, err := c.Run("Ascii")
	if err != nil {
		return "", err
	}
	return strings.Join(data, "\n"), nil
}

func (c *Client) AsciiField() (string, error) {
	data, _, err := c.Run("AsciiField")
	if err != nil {
		return "", err
	}
	return strings.Join(data, ""), nil
}

func (c *Client) SnapSave() error {
	_, _, err := c.Run("Snap(Save)")
	return err
}

func (c *Client) SnapAscii() (string, error) {
	data, _, err := c.Run("Snap(Ascii)")
	if err != nil {
		return "", err
	}
	return strings.Join(data, "\n"), nil
}

func (c *Client) Query(keyword string) (string, error) {
	cmd := "Query"
	if keyword != "" {
		cmd = fmt.Sprintf("Query(%s)", keyword)
	}
	data, _, err := c.Run(cmd)
	if err != nil {
		return "", err
	}
	return strings.Join(data, "\n"), nil
}

func (c *Client) Disconnect() error {
	_, _, err := c.Run("Disconnect")
	return err
}

// Source runs commands from a local s3270 script file inside the emulator.
func (c *Client) Source(file string) error {
	// Quote path for Windows backslashes by using forward slashes when possible.
	p := filepath.ToSlash(file)
	_, _, err := c.Run(fmt.Sprintf(`Source("%s")`, strings.ReplaceAll(p, `"`, `\"`)))
	return err
}

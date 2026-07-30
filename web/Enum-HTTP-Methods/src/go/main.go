package main

import (
	"context"
	"crypto/tls"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/fatih/color"
)

const version = "2.0"

func main() {
	urlFlag := flag.String("u", "", "target URL (required), e.g. https://example.com/")
	listFlag := flag.String("l", "", "file with target URLs (one per line)")
	auth := flag.String("auth", "", "Authorization header value (e.g. 'Bearer token')")
	headerFlags := flag.String("H", "", "extra headers as 'Key:Value,Key2:Value2'")
	timeout := flag.Duration("timeout", 10*time.Second, "request timeout")
	insecure := flag.Bool("k", false, "skip TLS certificate verification")
	noRedirect := flag.Bool("no-redirect", true, "do not follow redirects (recommended for method enum)")
	silent := flag.Bool("silent", false, "suppress banner")
	jsonOut := flag.Bool("json", false, "JSON lines output")
	flag.Parse()

	// Positional URL fallback: enum-http-methods https://host/
	if *urlFlag == "" && *listFlag == "" && flag.NArg() == 1 {
		*urlFlag = flag.Arg(0)
	}

	if !*silent && !*jsonOut {
		printBanner()
	}

	targets := []string{}
	if *urlFlag != "" {
		targets = append(targets, *urlFlag)
	}
	if *listFlag != "" {
		data, err := os.ReadFile(*listFlag)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error reading list: %v\n", err)
			os.Exit(1)
		}
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(strings.TrimSuffix(line, "\r"))
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			targets = append(targets, line)
		}
	}

	if len(targets) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: enum-http-methods -u <url> [-auth 'Bearer ...'] [-H 'X:Y']")
		fmt.Fprintln(os.Stderr, "       enum-http-methods -l urls.txt")
		flag.PrintDefaults()
		os.Exit(1)
	}

	extra := parseHeaders(*headerFlags)
	if *auth != "" {
		extra["Authorization"] = *auth
	}

	transport := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: *insecure}, //nolint:gosec
	}
	client := &http.Client{
		Timeout:   *timeout,
		Transport: transport,
	}
	if *noRedirect {
		client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		}
	}

	methods := []string{
		http.MethodGet,
		http.MethodHead,
		http.MethodPost,
		http.MethodPut,
		http.MethodPatch,
		http.MethodDelete,
		http.MethodOptions,
		http.MethodTrace,
		http.MethodConnect,
	}

	dangerous := map[string]bool{
		http.MethodPut: true, http.MethodDelete: true,
		http.MethodTrace: true, http.MethodConnect: true, http.MethodPatch: true,
	}

	for _, host := range targets {
		if !*jsonOut {
			fmt.Println("[+] Host:", color.YellowString("%s", host))
		}
		for _, method := range methods {
			ctx, cancel := context.WithTimeout(context.Background(), *timeout)
			code, text, allow, err := doMethod(ctx, client, method, host, extra)
			cancel()

			if err != nil {
				if *jsonOut {
					fmt.Printf(`{"url":%q,"method":%q,"error":%q}`+"\n", host, method, err.Error())
				} else {
					color.Red("%s failed: %v\n", method, err)
				}
				continue
			}

			interesting := code >= 200 && code < 300 && dangerous[method]
			if *jsonOut {
				fmt.Printf(`{"url":%q,"method":%q,"status":%d,"status_text":%q,"allow":%q,"interesting":%t}`+"\n",
					host, method, code, text, allow, interesting)
				continue
			}

			line := fmt.Sprintf("%-8s %d %s", method, code, text)
			switch {
			case interesting:
				color.Red("%s  ← review (dangerous method allowed?)\n", line)
			case code >= 200 && code < 300:
				color.Green("%s\n", line)
			case code >= 300 && code < 400:
				color.Cyan("%s\n", line)
			case code >= 400 && code < 500:
				color.Yellow("%s\n", line)
			default:
				color.Red("%s\n", line)
			}
			if method == http.MethodOptions && allow != "" {
				fmt.Println("         Allow:", color.MagentaString("%s", allow))
			}
		}
		if !*jsonOut {
			fmt.Println()
		}
	}
}

func doMethod(ctx context.Context, client *http.Client, method, rawURL string, headers map[string]string) (int, string, string, error) {
	req, err := http.NewRequestWithContext(ctx, method, rawURL, nil)
	if err != nil {
		return 0, "", "", err
	}
	req.Header.Set("User-Agent", "enum-http-methods/"+version)
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := client.Do(req)
	if err != nil {
		return 0, "", "", err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64*1024))

	allow := resp.Header.Get("Allow")
	if allow == "" {
		allow = resp.Header.Get("Access-Control-Allow-Methods")
	}
	return resp.StatusCode, http.StatusText(resp.StatusCode), allow, nil
}

func parseHeaders(raw string) map[string]string {
	out := make(map[string]string)
	if raw == "" {
		return out
	}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		i := strings.Index(part, ":")
		if i <= 0 {
			continue
		}
		k := strings.TrimSpace(part[:i])
		v := strings.TrimSpace(part[i+1:])
		out[k] = v
	}
	return out
}

func printBanner() {
	fmt.Println(color.GreenString(`
          _|_|_  _   .|| _  _  _ |_  _  _|  _  _
           | | |(/_\/|||(_|(_|(/_| |(_|(_|<(/_|
                            _|
                  ------------------
               ~ |Do Hacks to Secure| ~
                  ------------------
           HTTP Method Enumeration v` + version + `
`))
}

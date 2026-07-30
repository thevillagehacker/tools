package main

import (
	"context"
	"crypto/tls"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/fatih/color"
	"golang.org/x/net/html"

	banner "github.com/thevillagehacker/urlscrapper/modules"
)

const maxBodyBytes = 5 << 20 // 5 MiB

var (
	absURLRe = regexp.MustCompile(`(?i)https?://[^\s"'<>\\]+`)
	// protocol-relative
	protoRelRe = regexp.MustCompile(`(?i)//[a-zA-Z0-9][-a-zA-Z0-9.]*(?::[0-9]+)?/[^\s"'<>\\]*`)
)

func main() {
	urlFlag := flag.String("u", "", "target URL (required)")
	output := flag.String("o", "", "output file")
	statusCheck := flag.Bool("sc", false, "check status codes for discovered URLs")
	timeout := flag.Duration("timeout", 15*time.Second, "HTTP timeout")
	workers := flag.Int("c", 10, "concurrency for status checks")
	sameHost := flag.Bool("same-host", false, "only keep URLs on the same host as the target")
	silent := flag.Bool("silent", false, "suppress banner")
	insecure := flag.Bool("k", false, "skip TLS certificate verification")

	flag.Parse()

	if !*silent {
		banner.ShowBanner()
	}

	if *urlFlag == "" {
		fmt.Fprintln(os.Stderr, "error: -u target URL is required")
		flag.Usage()
		os.Exit(1)
	}

	target, err := url.Parse(*urlFlag)
	if err != nil || target.Scheme == "" || target.Host == "" {
		log.Fatalf("invalid URL: %s", *urlFlag)
	}
	if target.Scheme != "http" && target.Scheme != "https" {
		log.Fatalf("URL scheme must be http or https")
	}

	client := &http.Client{
		Timeout: *timeout,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: *insecure}, //nolint:gosec
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 10 {
				return fmt.Errorf("too many redirects")
			}
			return nil
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	body, finalURL, err := fetch(ctx, client, target.String())
	if err != nil {
		log.Fatal(err)
	}
	base, _ := url.Parse(finalURL)

	found := extractURLs(body, base)
	if *sameHost {
		host := strings.ToLower(base.Hostname())
		filtered := make([]string, 0, len(found))
		for _, u := range found {
			pu, err := url.Parse(u)
			if err != nil {
				continue
			}
			if strings.EqualFold(pu.Hostname(), host) {
				filtered = append(filtered, u)
			}
		}
		found = filtered
	}

	found = unique(found)
	if len(found) == 0 {
		fmt.Println("No matches.")
		return
	}

	var outFile *os.File
	if *output != "" {
		outFile, err = os.Create(*output)
		if err != nil {
			log.Fatalf("creating output: %v", err)
		}
		defer outFile.Close()
	}

	if *statusCheck {
		checkStatuses(client, found, *workers, outFile)
	} else {
		for _, link := range found {
			fmt.Println(link)
			if outFile != nil {
				fmt.Fprintln(outFile, link)
			}
		}
	}
}

func fetch(ctx context.Context, client *http.Client, raw string) ([]byte, string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, raw, nil)
	if err != nil {
		return nil, "", err
	}
	req.Header.Set("User-Agent", "urlscrapper/2.0 (+https://github.com/thevillagehacker/tools)")

	resp, err := client.Do(req)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()

	limited := io.LimitReader(resp.Body, maxBodyBytes)
	data, err := io.ReadAll(limited)
	if err != nil {
		return nil, "", fmt.Errorf("reading body: %w", err)
	}
	final := raw
	if resp.Request != nil && resp.Request.URL != nil {
		final = resp.Request.URL.String()
	}
	return data, final, nil
}

func extractURLs(body []byte, base *url.URL) []string {
	seen := make(map[string]struct{})
	var out []string
	add := func(raw string) {
		raw = strings.TrimSpace(raw)
		raw = strings.Trim(raw, `"'`)
		raw = strings.TrimRight(raw, `).,;]`)
		if raw == "" || strings.HasPrefix(raw, "javascript:") || strings.HasPrefix(raw, "mailto:") || strings.HasPrefix(raw, "data:") {
			return
		}
		// protocol-relative
		if strings.HasPrefix(raw, "//") {
			raw = base.Scheme + ":" + raw
		}
		u, err := url.Parse(raw)
		if err != nil {
			return
		}
		resolved := base.ResolveReference(u)
		if resolved.Scheme != "http" && resolved.Scheme != "https" {
			return
		}
		// drop fragments for dedup stability
		resolved.Fragment = ""
		s := resolved.String()
		if _, ok := seen[s]; ok {
			return
		}
		seen[s] = struct{}{}
		out = append(out, s)
	}

	// HTML attribute crawl
	doc, err := html.Parse(strings.NewReader(string(body)))
	if err == nil {
		var walk func(*html.Node)
		walk = func(n *html.Node) {
			if n.Type == html.ElementNode {
				for _, a := range n.Attr {
					switch strings.ToLower(a.Key) {
					case "href", "src", "action", "data-src", "data-url", "poster", "cite", "formaction":
						add(a.Val)
					case "srcset":
						for _, part := range strings.Split(a.Val, ",") {
							part = strings.TrimSpace(part)
							if fields := strings.Fields(part); len(fields) > 0 {
								add(fields[0])
							}
						}
					}
				}
			}
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				walk(c)
			}
		}
		walk(doc)
	}

	// Regex fallback for absolute / protocol-relative in scripts and text
	for _, m := range absURLRe.FindAllString(string(body), -1) {
		add(m)
	}
	for _, m := range protoRelRe.FindAllString(string(body), -1) {
		add(m)
	}

	return out
}

func unique(in []string) []string {
	seen := make(map[string]struct{}, len(in))
	out := make([]string, 0, len(in))
	for _, s := range in {
		if _, ok := seen[s]; ok {
			continue
		}
		seen[s] = struct{}{}
		out = append(out, s)
	}
	return out
}

func checkStatuses(client *http.Client, urls []string, workers int, outFile *os.File) {
	if workers < 1 {
		workers = 1
	}
	jobs := make(chan string)
	var wg sync.WaitGroup
	var mu sync.Mutex

	worker := func() {
		defer wg.Done()
		for link := range jobs {
			resp, err := client.Get(link)
			if err != nil {
				line := fmt.Sprintf("%s - error: %v", link, err)
				mu.Lock()
				fmt.Println(line)
				if outFile != nil {
					fmt.Fprintln(outFile, line)
				}
				mu.Unlock()
				continue
			}
			code := resp.StatusCode
			resp.Body.Close()
			colored := colorStatus(code)
			mu.Lock()
			fmt.Printf("%s - %s\n", link, colored)
			if outFile != nil {
				fmt.Fprintf(outFile, "%s - %d\n", link, code)
			}
			mu.Unlock()
		}
	}

	wg.Add(workers)
	for i := 0; i < workers; i++ {
		go worker()
	}
	for _, u := range urls {
		jobs <- u
	}
	close(jobs)
	wg.Wait()
}

func colorStatus(code int) string {
	switch {
	case code >= 200 && code < 300:
		return color.GreenString("%d", code)
	case code >= 300 && code < 400:
		return color.YellowString("%d", code)
	case code == 401 || code == 403:
		return color.RedString("%d", code)
	case code == 404:
		return color.BlueString("%d", code)
	case code >= 500:
		return color.RedString("%d", code)
	default:
		return fmt.Sprintf("%d", code)
	}
}


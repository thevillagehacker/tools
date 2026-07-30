package banner

import "fmt"

const banner = `
            	URL Scrapper
             ------------------
          ~ |Do Hacks to Secure| ~
             ------------------             v2.0
                    By
`

// Version is the current version of urlscrapper
const Version = `v2.0`

// ShowBanner prints the tool banner and disclaimer.
func ShowBanner() {
	fmt.Printf("%s\n", banner)
	fmt.Printf("\tThe Village Hacker Security\n\n")
	fmt.Printf("Use with caution. You are responsible for your actions.\n")
	fmt.Printf("Developers assume no liability and are not responsible for any misuse or damages.\n")
	fmt.Printf("--------------------------------------------------------------------------------- \n")
}

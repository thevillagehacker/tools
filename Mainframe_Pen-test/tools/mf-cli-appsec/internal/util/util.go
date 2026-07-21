package util

import "fmt"

// GenerateEMPIDs creates zero-padded sample IDs (width 6) for canary-range testing.
func GenerateEMPIDs(start, count int) []string {
	return GenerateIDs(start, count, 6)
}

// GenerateIDs creates zero-padded numeric IDs of any width (accounts, cases, empids, …).
// Keep ranges small and authorized — do not blast production sequences.
func GenerateIDs(start, count, width int) []string {
	if width < 1 {
		width = 6
	}
	if count < 0 {
		count = 0
	}
	out := make([]string, 0, count)
	fmtStr := fmt.Sprintf("%%0%dd", width)
	for i := 0; i < count; i++ {
		out = append(out, fmt.Sprintf(fmtStr, start+i))
	}
	return out
}

func DefaultFuzzPayloads() []string {
	return []string{
		`'`,
		`"`,
		`;`,
		`|`,
		`&`,
		`*`,
		`%`,
		`../`,
		`../../`,
		`OR 1=1`,
		`' OR '1'='1`,
		`0`,
		`-1`,
		`999999999`,
		`AAAAAAAAAA`,
		`AAAAAAAAAAAAAAA`,
		`{{`,
		`}}`,
		`/*`,
		`--`,
	}
}

// Minimal EBCDIC-US (CP037) conversion for common printable ASCII.
// Good enough for text dumps; not a full codec for binary.

var asciiToEBCDIC [256]byte
var ebcdicToASCII [256]byte

func init() {
	for i := 0; i < 256; i++ {
		asciiToEBCDIC[i] = byte(i)
		ebcdicToASCII[i] = byte(i)
	}
	// Digits 0-9
	for i := 0; i < 10; i++ {
		asciiToEBCDIC[0x30+i] = byte(0xF0 + i)
	}
	// A-I, J-R, S-Z
	for i := 0; i < 9; i++ {
		asciiToEBCDIC['A'+i] = byte(0xC1 + i)
		asciiToEBCDIC['J'+i] = byte(0xD1 + i)
	}
	for i := 0; i < 8; i++ {
		asciiToEBCDIC['S'+i] = byte(0xE2 + i)
	}
	// a-i, j-r, s-z
	for i := 0; i < 9; i++ {
		asciiToEBCDIC['a'+i] = byte(0x81 + i)
		asciiToEBCDIC['j'+i] = byte(0x91 + i)
	}
	for i := 0; i < 8; i++ {
		asciiToEBCDIC['s'+i] = byte(0xA2 + i)
	}
	asciiToEBCDIC[' '] = 0x40
	asciiToEBCDIC['.'] = 0x4B
	asciiToEBCDIC['<'] = 0x4C
	asciiToEBCDIC['('] = 0x4D
	asciiToEBCDIC['+'] = 0x4E
	asciiToEBCDIC['|'] = 0x4F
	asciiToEBCDIC['&'] = 0x50
	asciiToEBCDIC['!'] = 0x5A
	asciiToEBCDIC['$'] = 0x5B
	asciiToEBCDIC['*'] = 0x5C
	asciiToEBCDIC[')'] = 0x5D
	asciiToEBCDIC[';'] = 0x5E
	asciiToEBCDIC['-'] = 0x60
	asciiToEBCDIC['/'] = 0x61
	asciiToEBCDIC[','] = 0x6B
	asciiToEBCDIC['%'] = 0x6C
	asciiToEBCDIC['_'] = 0x6D
	asciiToEBCDIC['>'] = 0x6E
	asciiToEBCDIC['?'] = 0x6F
	asciiToEBCDIC[':'] = 0x7A
	asciiToEBCDIC['#'] = 0x7B
	asciiToEBCDIC['@'] = 0x7C
	asciiToEBCDIC['\''] = 0x7D
	asciiToEBCDIC['='] = 0x7E
	asciiToEBCDIC['"'] = 0x7F

	for a := 0; a < 256; a++ {
		e := asciiToEBCDIC[a]
		if a >= 32 && a < 127 {
			ebcdicToASCII[e] = byte(a)
		}
	}
	ebcdicToASCII[0x40] = ' '
}

func ASCIIToEBCDIC(in []byte) []byte {
	out := make([]byte, len(in))
	for i, b := range in {
		out[i] = asciiToEBCDIC[b]
	}
	return out
}

func EBCDICToASCII(in []byte) []byte {
	out := make([]byte, len(in))
	for i, b := range in {
		out[i] = ebcdicToASCII[b]
	}
	return out
}

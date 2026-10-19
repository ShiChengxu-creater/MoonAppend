// Independent test adapter. Upstream algorithms are imported, not copied.
package main

import (
	"bufio"
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/transparency-dev/merkle/proof"
	"github.com/transparency-dev/merkle/rfc6962"
	"github.com/transparency-dev/merkle/testonly"
)

func number(s string) uint64 {
	n, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err)
	}
	return n
}

func path(s string) [][]byte {
	result := [][]byte{}
	if s == "" {
		return result
	}
	for _, item := range strings.Split(s, ",") {
		node, err := hex.DecodeString(item)
		if err != nil {
			panic(err)
		}
		result = append(result, node)
	}
	return result
}

func equalPath(a, b [][]byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if !bytes.Equal(a[i], b[i]) {
			return false
		}
	}
	return true
}

func check() {
	hasher := rfc6962.DefaultHasher
	tree := testonly.New(hasher)
	for i := 0; i < 129; i++ {
		tree.AppendData([]byte{byte(i), 0, 255})
	}
	counts := map[string]int{"roots": 0, "inclusion": 0, "consistency": 0}
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		f := strings.Split(scanner.Text(), "\t")
		switch f[0] {
		case "R":
			if len(f) != 3 {
				panic("invalid root record")
			}
			if hex.EncodeToString(tree.HashAt(number(f[1]))) != f[2] {
				panic("root mismatch")
			}
			counts["roots"]++
		case "I":
			if len(f) != 4 {
				panic("invalid inclusion record")
			}
			size, index, nodes := number(f[1]), number(f[2]), path(f[3])
			want, err := tree.InclusionProof(index, size)
			if err != nil {
				panic(err)
			}
			if !equalPath(want, nodes) {
				panic("inclusion generation differs")
			}
			if err := proof.VerifyInclusion(hasher, index, size, tree.LeafHash(index), nodes, tree.HashAt(size)); err != nil {
				panic(err)
			}
			counts["inclusion"]++
		case "C":
			if len(f) != 4 {
				panic("invalid consistency record")
			}
			old, newSize, nodes := number(f[1]), number(f[2]), path(f[3])
			want, err := tree.ConsistencyProof(old, newSize)
			if err != nil {
				panic(err)
			}
			if !equalPath(want, nodes) {
				panic("consistency generation differs")
			}
			if err := proof.VerifyConsistency(hasher, old, newSize, nodes, tree.HashAt(old), tree.HashAt(newSize)); err != nil {
				panic(err)
			}
			counts["consistency"]++
		default:
			panic("unknown record")
		}
	}
	if err := scanner.Err(); err != nil {
		panic(err)
	}
	if err := json.NewEncoder(os.Stdout).Encode(counts); err != nil {
		panic(err)
	}
}

func main() {
	if len(os.Args) == 2 && os.Args[1] == "check" {
		check()
		return
	}
	fmt.Fprintln(os.Stderr, "usage: reference check")
	os.Exit(2)
}

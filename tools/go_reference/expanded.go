package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"strings"

	"github.com/transparency-dev/merkle/compact"
	"github.com/transparency-dev/merkle/rfc6962"
	"github.com/transparency-dev/merkle/testonly"
)

func checkExpanded() {
	h := rfc6962.DefaultHasher
	f := &compact.RangeFactory{Hash: h.HashChildren}
	tree := testonly.New(h)
	for i := 0; i < 33; i++ {
		tree.AppendData([]byte{byte(i), 0, 255})
	}
	makeRange := func(start, end uint64) *compact.Range {
		r := f.NewEmptyRange(start)
		for i := start; i < end; i++ {
			if err := r.Append(tree.LeafHash(i), nil); err != nil {
				panic(err)
			}
		}
		return r
	}
	counts := map[string]int{"compact_ranges": 0, "range_proofs": 0}
	scanner := bufio.NewScanner(os.Stdin)
	seen := map[string]bool{}
	for scanner.Scan() {
		line := scanner.Text()
		if seen[line] {
			panic("duplicate record")
		}
		seen[line] = true
		fields := strings.Split(line, "\t")
		switch fields[0] {
		case "K":
			if len(fields) != 4 {
				panic("invalid compact record")
			}
			start, end := number(fields[1]), number(fields[2])
			if start > end || end > 33 || !equalPath(makeRange(start, end).Hashes(), path(fields[3])) {
				panic("compact range differs")
			}
			counts["compact_ranges"]++
		case "Q":
			if len(fields) != 5 {
				panic("invalid range record")
			}
			start, end, size := number(fields[1]), number(fields[2]), number(fields[3])
			if start >= end || end > size || size > 33 {
				panic("invalid bounds")
			}
			left, right := makeRange(0, start), makeRange(end, size)
			expected := append(append([][]byte{}, left.Hashes()...), right.Hashes()...)
			actual := path(fields[4])
			if !equalPath(expected, actual) {
				panic("range witness differs")
			}
			a, err := f.NewRange(0, start, append([][]byte{}, actual[:len(left.Hashes())]...))
			if err != nil {
				panic(err)
			}
			b, err := f.NewRange(end, size, append([][]byte{}, actual[len(left.Hashes()):]...))
			if err != nil {
				panic(err)
			}
			if err := a.AppendRange(makeRange(start, end), nil); err != nil {
				panic(err)
			}
			if err := a.AppendRange(b, nil); err != nil {
				panic(err)
			}
			root, err := a.GetRootHash(nil)
			if err != nil || !bytes.Equal(root, tree.HashAt(size)) {
				panic("range root differs")
			}
			counts["range_proofs"]++
		default:
			panic("unknown expanded record")
		}
	}
	if err := scanner.Err(); err != nil {
		panic(err)
	}
	if counts["compact_ranges"] != 595 || counts["range_proofs"] != 6545 {
		panic("incomplete fixture")
	}
	if err := json.NewEncoder(os.Stdout).Encode(counts); err != nil {
		panic(err)
	}
}

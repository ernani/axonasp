/*
 * AxonASP Server
 * Copyright (C) 2026 G3pix Ltda. All rights reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */
package axonvm

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestJScriptDuplicateNestedIncludeDeclarations(t *testing.T) {
	root := t.TempDir()
	shared := filepath.Join(root, "shared.inc")
	first := filepath.Join(root, "first.inc")
	second := filepath.Join(root, "second.inc")
	page := filepath.Join(root, "index.asp")

	var declarations strings.Builder
	declarations.WriteString("<%\nvar includeRuns = (typeof includeRuns == 'undefined' ? 0 : includeRuns) + 1;\n")
	for i := range 400 {
		fmt.Fprintf(&declarations, "var sharedConstant%03d = %d;\n", i, i)
	}
	declarations.WriteString("%>\n")

	files := map[string]string{
		shared: declarations.String(),
		first:  "<!--#include file=\"shared.inc\"-->\n<% function helper() { return true; } var firstLoaded = true; %>\n",
		second: "<!--#include file=\"shared.inc\"-->\n<% var secondLoaded = true; %>\n",
		page: "<%@ language=JavaScript %>\n" +
			"<!--#include file=\"first.inc\"-->\n" +
			"<!--#include file=\"second.inc\"-->\n" +
			"<%= includeRuns + '|' + sharedConstant399 + '|' + firstLoaded + '|' + secondLoaded %>",
	}
	for path, content := range files {
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatalf("write fixture %s: %v", filepath.Base(path), err)
		}
	}

	compiler := NewASPCompiler(files[page])
	compiler.SetSourceName(page)
	compiler.SetIncludeSiteRoot(root)
	if err := compiler.Compile(); err != nil {
		t.Fatalf("compile duplicate nested includes: %v", err)
	}
	if got := countOpcode(compiler.bytecode, OpJSDeclareName); got != 404 {
		t.Fatalf("duplicate includes must hoist each top-level var once: got %d declarations, want 404", got)
	}

	vm := NewVM(compiler.Bytecode(), compiler.Constants(), compiler.GlobalsCount())
	host := NewMockHost()
	var output bytes.Buffer
	host.SetOutput(&output)
	host.Response().SetBuffer(false)
	vm.SetHost(host)
	if err := vm.Run(); err != nil {
		t.Fatalf("run duplicate nested includes: %v", err)
	}
	if got := strings.TrimSpace(output.String()); got != "2|399|true|true" {
		t.Fatalf("unexpected output: got %q", got)
	}
}

func TestJScriptDuplicateTopLevelVarDeclarationBytecodeIsBalanced(t *testing.T) {
	source := `<%@ language=JavaScript %><% var repeated = 1; var repeated = 2; %><%= repeated %>`
	compiler := NewASPCompiler(source)
	if err := compiler.Compile(); err != nil {
		t.Fatalf("compile duplicate declaration: %v", err)
	}

	declareCount := countOpcode(compiler.bytecode, OpJSDeclareName)
	setCount := 0
	for ip := 0; ip < len(compiler.bytecode); {
		op := OpCode(compiler.bytecode[ip])
		switch op {
		case OpJSSetName, OpJSSetLocal:
			setCount++
		}
		ip += 1 + opcodeOperandSize(op, compiler.bytecode, ip)
	}
	if declareCount != 1 {
		t.Fatalf("duplicate var must be hoisted once, got %d declarations", declareCount)
	}
	if setCount != 2 {
		t.Fatalf("both duplicate var initializers must execute, got %d stores", setCount)
	}
}

func countOpcode(bytecode []byte, want OpCode) int {
	count := 0
	for ip := 0; ip < len(bytecode); {
		op := OpCode(bytecode[ip])
		if op == want {
			count++
		}
		ip += 1 + opcodeOperandSize(op, bytecode, ip)
	}
	return count
}

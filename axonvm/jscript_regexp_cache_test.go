package axonvm

import "testing"

func TestJScriptRegExpCompiledProgramCacheUsesPatternAndFlags(t *testing.T) {
	vm := NewVM(nil, nil, 0)

	plain, err := vm.jsCompileRegExp("^alpha$", "")
	if err != nil {
		t.Fatal(err)
	}
	plainAgain, err := vm.jsCompileRegExp("^alpha$", "")
	if err != nil {
		t.Fatal(err)
	}
	if plain != plainAgain {
		t.Fatal("identical pattern and flags did not reuse the compiled program")
	}

	ignoreCase, err := vm.jsCompileRegExp("^alpha$", "i")
	if err != nil {
		t.Fatal(err)
	}
	multiline, err := vm.jsCompileRegExp("^alpha$", "m")
	if err != nil {
		t.Fatal(err)
	}
	if plain == ignoreCase || plain == multiline || ignoreCase == multiline {
		t.Fatal("different compile-affecting flags shared a compiled program")
	}

	global, err := vm.jsCompileRegExp("^alpha$", "g")
	if err != nil {
		t.Fatal(err)
	}
	globalAgain, err := vm.jsCompileRegExp("^alpha$", "g")
	if err != nil {
		t.Fatal(err)
	}
	if global == plain || global != globalAgain {
		t.Fatal("cache did not distinguish and reuse the global flag combination")
	}
}

func TestJScriptRegExpCompiledProgramCacheSurvivesPooledReset(t *testing.T) {
	vm := NewVM(nil, nil, 0)
	compiled, err := vm.jsCompileRegExp("a+", "im")
	if err != nil {
		t.Fatal(err)
	}

	vm.captureBaseProgramState()
	vm.resetForReuse()

	afterReset, err := vm.jsCompileRegExp("a+", "im")
	if err != nil {
		t.Fatal(err)
	}
	if compiled != afterReset {
		t.Fatal("pooled reset discarded the compiled regexp program")
	}
}

func TestJScriptRegExpCachePreservesFlagsAndPerObjectLastIndex(t *testing.T) {
	source := `<script runat="server" language="JScript">` +
		`var a = new RegExp("^x", "gim");` +
		`var b = new RegExp("^x", "gim");` +
		`Response.Write(a.test("z\nX") + ":" + a.lastIndex + ":" + b.lastIndex + "|");` +
		`Response.Write(a.test("z\nX") + ":" + a.lastIndex + ":" + b.test("x") + ":" + b.lastIndex);` +
		`</script>`

	out := runASPSourceForTest(t, source)
	if out != "true:3:0|false:0:true:1" {
		t.Fatalf("unexpected regexp flags/lastIndex output: %q", out)
	}
}

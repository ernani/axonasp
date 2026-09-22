package axonvm

import "testing"

func TestJScriptReleasedEnvironmentBindingsAreReusedCleared(t *testing.T) {
	vm := NewVM(nil, nil, 0)
	envID := vm.allocJSEnvID()
	if _, exists := vm.jsObjectKeyOrder[envID]; exists {
		t.Fatal("environment ID allocated object key-order state")
	}
	bindings := map[string]Value{"stale": NewString("value")}
	vm.jsEnvItems[envID] = &jsEnvFrame{bindings: bindings}

	vm.jsReleaseEnvFrame(envID)
	if _, exists := vm.jsEnvItems[envID]; exists {
		t.Fatal("released environment remains active")
	}
	if len(vm.jsEnvBindingsPool) != 1 {
		t.Fatalf("expected one reusable bindings map, got %d", len(vm.jsEnvBindingsPool))
	}

	reused := vm.jsAcquireEnvBindings(2)
	if _, exists := reused["stale"]; exists {
		t.Fatal("reused bindings map retained a stale value")
	}
	if len(vm.jsEnvBindingsPool) != 0 {
		t.Fatal("acquired bindings map remains in pool")
	}
}

func TestJScriptCapturedEnvironmentBindingsAreNotReused(t *testing.T) {
	vm := NewVM(nil, nil, 0)
	envID := vm.allocJSEnvID()
	vm.jsEnvItems[envID] = &jsEnvFrame{
		bindings:         map[string]Value{"captured": NewString("value")},
		capturedClosures: 1,
	}

	vm.jsReleaseEnvFrame(envID)
	if _, exists := vm.jsEnvItems[envID]; !exists {
		t.Fatal("captured environment was released")
	}
	if len(vm.jsEnvBindingsPool) != 0 {
		t.Fatal("captured environment bindings entered reuse pool")
	}
}

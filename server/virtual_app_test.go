package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestVirtualAppMetadataAndMapPath(t *testing.T) {
	oldAlias, oldRoot := VirtualAppPath, RootDir
	VirtualAppPath = "/portal"
	RootDir = t.TempDir()
	t.Cleanup(func() { VirtualAppPath, RootDir = oldAlias, oldRoot })

	req := httptest.NewRequest(http.MethodGet, "http://example.test/portal/docs/probe.asp", nil)
	host := NewWebHost(httptest.NewRecorder(), req)
	variables := host.Request().ServerVars
	for key, expected := range map[string]string{
		"APPL_MD_PATH":       "/LM/W3SVC/1/ROOT/portal",
		"INSTANCE_META_PATH": "/LM/W3SVC/1",
		"URL":                "/portal/docs/probe.asp",
		"PATH_INFO":          "/portal/docs/probe.asp",
		"SCRIPT_NAME":        "/portal/docs/probe.asp",
		"APPL_PHYSICAL_PATH": RootDir,
		"PATH_TRANSLATED":    filepath.Join(RootDir, "docs", "probe.asp"),
	} {
		if got := variables.Get(key); got != expected {
			t.Errorf("%s: got %q, want %q", key, got, expected)
		}
	}
	if got := host.Server().MapPath("../settings.json"); got != filepath.Join(RootDir, "settings.json") {
		t.Errorf("relative MapPath: %q", got)
	}
}

func TestVirtualAppSessionCookiePath(t *testing.T) {
	oldAlias := VirtualAppPath
	VirtualAppPath = "/portal"
	t.Cleanup(func() { VirtualAppPath = oldAlias })
	rec := httptest.NewRecorder()
	NewWebHost(rec, httptest.NewRequest(http.MethodGet, "http://example.test/portal/docs/main.asp", nil))
	if got := sessionCookieFromResponse(t, rec).Path; got != "/portal/" {
		t.Fatalf("session cookie path = %q, want /portal/", got)
	}
	if rootPath := virtualAppCookiePath(""); rootPath != "/" {
		t.Fatalf("root cookie path changed: %q", rootPath)
	}
}

func TestVirtualAppScriptResolution(t *testing.T) {
	oldAlias, oldRoot, oldConfig := VirtualAppPath, RootDir, activeWebConfig
	VirtualAppPath = "/portal"
	RootDir = t.TempDir()
	activeWebConfig = nil
	t.Cleanup(func() { VirtualAppPath, RootDir, activeWebConfig = oldAlias, oldRoot, oldConfig })
	if err := os.MkdirAll(filepath.Join(RootDir, "docs"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(RootDir, "docs", "probe.asp"), []byte(`<%@ Language=JavaScript %><% Response.Write(Request.ServerVariables("URL") + "|" + Request.ServerVariables("APPL_MD_PATH") + "|" + Server.MapPath("../settings.json")); %>`), 0600); err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	handleRequest(rec, httptest.NewRequest(http.MethodGet, "http://example.test/portal/docs/probe.asp", nil))
	if rec.Code != 200 || rec.Body.String() != "/portal/docs/probe.asp|/LM/W3SVC/1/ROOT/portal|"+filepath.Join(RootDir, "settings.json") {
		t.Fatalf("unexpected script response: status %d, body %q", rec.Code, rec.Body.String())
	}
}

func TestVirtualAppRouteResolvesFilesWithoutExposingRoot(t *testing.T) {
	oldAlias, oldRoot, oldConfig := VirtualAppPath, RootDir, activeWebConfig
	VirtualAppPath = "/portal"
	RootDir = t.TempDir()
	activeWebConfig = nil
	t.Cleanup(func() { VirtualAppPath, RootDir, activeWebConfig = oldAlias, oldRoot, oldConfig })
	if err := os.WriteFile(filepath.Join(RootDir, "asset.txt"), []byte("asset-ok"), 0600); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		path string
		code int
		body string
	}{
		{"/portal/asset.txt", 200, "asset-ok"},
		{"/asset.txt", 404, ""},
		{"/portal-other/asset.txt", 404, ""},
	} {
		rec := httptest.NewRecorder()
		handleRequest(rec, httptest.NewRequest(http.MethodGet, "http://example.test"+tc.path, nil))
		if rec.Code != tc.code || (tc.body != "" && rec.Body.String() != tc.body) {
			t.Errorf("%s: status %d, body %q", tc.path, rec.Code, rec.Body.String())
		}
	}
}

func TestVirtualAppPathValidation(t *testing.T) {
	for _, alias := range []string{"/portal", "/v2.1", "/v_1-test"} {
		if !validVirtualAppPath(alias) {
			t.Errorf("rejected valid alias %q", alias)
		}
	}
	for _, alias := range []string{"", "/", "portal", "/../x", "/v2.1/docs", "/%2F", "/a\\b"} {
		if validVirtualAppPath(alias) {
			t.Errorf("accepted invalid alias %q", alias)
		}
	}
}

func TestRootMetadataUnchangedWithoutAlias(t *testing.T) {
	app, instance := virtualAppMetadata("")
	if app != "/LM/W3SVC/1/ROOT" || instance != "/LM/W3SVC/1/ROOT" {
		t.Fatalf("root metadata changed: %q, %q", app, instance)
	}
}

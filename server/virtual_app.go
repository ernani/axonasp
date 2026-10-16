package main

import "strings"

// validVirtualAppPath permits a single application alias, not an arbitrary
// filesystem or URL path supplied by a request.
func validVirtualAppPath(alias string) bool {
	if !strings.HasPrefix(alias, "/") || len(alias) < 2 || strings.ContainsAny(alias[1:], "/\\%?#") {
		return false
	}
	for _, r := range alias[1:] {
		if (r < 'a' || r > 'z') && (r < 'A' || r > 'Z') && (r < '0' || r > '9') && r != '.' && r != '_' && r != '-' {
			return false
		}
	}
	return alias != "/." && alias != "/.."
}

func virtualAppMetadata(alias string) (appPath, instancePath string) {
	if alias == "" {
		return "/LM/W3SVC/1/ROOT", "/LM/W3SVC/1/ROOT"
	}
	return "/LM/W3SVC/1/ROOT" + alias, "/LM/W3SVC/1"
}

func virtualAppCookiePath(alias string) string {
	if alias == "" {
		return "/"
	}
	return alias + "/"
}

//go:build !wasm && !lib_adodb_disabled

/*
 * AxonASP Server
 * Copyright (C) 2026 G3pix Ltda. All rights reserved.
 *
 * Developed by Yuri Eisman (@yeisman)
 * Contact: https://g3pix.com.br
 * Project URL: https://g3pix.com.br/axonasp
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Attribution Notice:
 * If this software is used in other projects, the name "AxonASP Server"
 * must be cited in the documentation or "About" section.
 *
 * Contribution Policy:
 * Modifications to the core source code of AxonASP Server must be
 * made available under this same license terms.
 */

package axonvm

import "testing"

func TestADODBSQLServerGUIDTextMatchesADO(t *testing.T) {
	// Wire bytes of uniqueidentifier '6F9619FF-8B86-D011-B42D-00C04FC964FF' (first three groups little-endian).
	raw := []byte{0xFF, 0x19, 0x96, 0x6F, 0x86, 0x8B, 0x11, 0xD0, 0xB4, 0x2D, 0x00, 0xC0, 0x4F, 0xC9, 0x64, 0xFF}
	if got := adodbSQLServerGUIDText(raw); got != "{6F9619FF-8B86-D011-B42D-00C04FC964FF}" {
		t.Fatalf("got %v", got)
	}
	if got := adodbSQLServerGUIDText(nil); got != nil {
		t.Fatalf("NULL must stay nil, got %v", got)
	}
}

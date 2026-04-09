---
title: "Required Source Disclosure"
description: "Source code for components where the license requires disclosure."
weight: 2
---

## Required Source Disclosure

The following components are distributed under licenses that require us to
make source code available. Links point to the exact source archives used
in this release build.

| Component | Version | License | Source |
|-----------|---------|---------|--------|
| audit | 4.1.2 | [GPL-2.0-or-later](https://spdx.org/licenses/GPL-2.0-or-later.html) | [source](https://github.com/linux-audit/audit-userspace/archive/cb13fe75ee2c36d5c525ed9de22aae10dbc8caf4.tar.gz) |
| bash-interactive | 5.3p9 | [GPL-3.0-or-later](https://spdx.org/licenses/GPL-3.0-or-later.html) | [source](https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz) |
| busybox | 1.37.0 | [GPL-2.0-only](https://spdx.org/licenses/GPL-2.0-only.html) | [source](https://busybox.net/downloads/busybox-1.37.0.tar.bz2) |
| db | 4.8.30 | [Sleepycat](https://spdx.org/licenses/Sleepycat.html) | [source](https://download.oracle.com/berkeley-db/db-4.8.30.tar.gz) |
| gcc | 15.2.0 | [GPL-3.0-or-later](https://spdx.org/licenses/GPL-3.0-or-later.html) | [source](https://mirror.koddos.net/gcc/releases/gcc-15.2.0/gcc-15.2.0.tar.xz) |
| glibc | 2.42 | [LGPL-2.0-or-later](https://spdx.org/licenses/LGPL-2.0-or-later.html) | [source](https://ftpmirror.gnu.org/glibc/glibc-2.42.tar.xz) |
| keyutils | 1.6.3 | [GPL-2.0-or-later](https://spdx.org/licenses/GPL-2.0-or-later.html) | [source](https://git.kernel.org/pub/scm/linux/kernel/git/dhowells/keyutils.git/snapshot/keyutils-1.6.3.tar.gz) |
| libcap-ng | 0.9 | [LGPL-2.1-only](https://spdx.org/licenses/LGPL-2.1-only.html) | [source](https://github.com/stevegrubb/libcap-ng/archive/refs/tags/v0.9.tar.gz) |
| libidn2 | 2.3.8 | [GPL-2.0-or-later](https://spdx.org/licenses/GPL-2.0-or-later.html) | [source](https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz) |
| libunistring | 1.4.1 | [LGPL-3.0-or-later](https://spdx.org/licenses/LGPL-3.0-or-later.html) | [source](https://ftpmirror.gnu.org/libunistring/libunistring-1.4.1.tar.gz) |
| libxcrypt | 4.5.2 | [LGPL-2.1-or-later](https://spdx.org/licenses/LGPL-2.1-or-later.html) | [source](https://github.com/besser82/libxcrypt/releases/download/v4.5.2/libxcrypt-4.5.2.tar.xz) |
| nss-cacert | 3.121 | [MPL-2.0](https://spdx.org/licenses/MPL-2.0.html) | [source](https://raw.githubusercontent.com/nss-dev/nss/refs/tags/NSS_3_121_RTM/lib/ckfw/builtins/certdata.txt) |
| readline | 8.3p3 | [GPL-3.0-or-later](https://spdx.org/licenses/GPL-3.0-or-later.html) | [source](https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz) |
| xgcc | 15.2.0 | [GPL-3.0-or-later](https://spdx.org/licenses/GPL-3.0-or-later.html) | [source](https://mirror.koddos.net/gcc/releases/gcc-15.2.0/gcc-15.2.0.tar.xz) |

## All Other Components

Source URLs for all components (including permissively-licensed ones) are
recorded in the CycloneDX SBOM under the `externalReferences` field with
type `distribution`. Download the SBOM from the
[Dependencies](../dependencies/) section to access them.

All images are built using [Nix](https://nixos.org/) derivations from pinned
inputs, ensuring the source URL in the SBOM is the exact archive used in the
build — not a "latest" pointer.

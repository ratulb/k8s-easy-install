# Revival change log

Tracking updates made during the 2026 revival of k8s-easy-install.

## P0 — Core install pipeline (done)

### `install-kubeadm.sh` — rewritten
- **Kubernetes repo**: `packages.cloud.google.com/apt` → `pkgs.k8s.io/core:/stable:/v1.36/deb/` with `signed-by` GPG keyring
- **Package pin**: apt pin (priority 1001) + `--allow-downgrades` so k8s components win over cloud-sdk kubectl
- **`apt-mark hold`** on kubelet/kubeadm/kubectl
- **Kernel modules**: `overlay` + `br_netfilter` loaded persistently via `/etc/modules-load.d/k8s.conf`
- **Sysctl**: `net.bridge.bridge-nf-call-ip6tables`, `net.bridge.bridge-nf-call-iptables`, `net.ipv4.ip_forward`
- **Docker removal**: if Docker present, `apt purge` docker-ce packages
- **Containerd config**: regenerated from defaults, `SystemdCgroup = true` (fixes `disabled_plugins = ["cri"]` left behind by Docker)

### `install-cni-pluggin.sh` — Weave → Calico
- Weave (archived upstream) replaced with **Calico v3.32.1**
- Uses the standard manifest: `kubectl apply -f manifests/calico.yaml`

### `install-docker.sh` — no-op
- Docker is no longer used; file replaced with a notice.
- All commented-out `. install-docker.sh` lines removed from `launch-cluster.sh`.

### `launch-cluster.sh` — cleanup
- Removed 4 commented-out Docker references.
- Prompt text fixed (`Installing docker kubeadm kubelet kubectl` → `Installing kubelet kubeadm kubectl`).

### Documentation
- `AGENTS.md`: stale section updated with ✅/pending per item, gotchas updated.
- `README.md`: Docker/containerd references corrected.
- `CHANGES.md`: this file.

## P1 — Load balancer + cleanup (done)

### `envoy/install-envoy.script` — rewritten
- Dead repos (`getenvoy.io/gpg`, `dl.bintray.com/tetrate/getenvoy-deb`) replaced with official Envoy apt repo at `https://apt.envoyproxy.io/`.
- Uses `signed-by` GPG keyring format (no `apt-key`).
- Uses `lsb_release -cs` for distro codename detection (works on Debian trixie/bookworm/bullseye and Ubuntu focal/jammy/noble).

### `kube-remove.sh` — added containerd reset
- Containerd is stopped, data directory (`/var/lib/containerd`) removed, config regenerated from defaults with `SystemdCgroup = true`, then restarted.
- Ensures a clean containerd state before re-installing k8s on a node.

## P2 — Minor fixes (done)

### `test-commands.sh` — taint label + role grep
- Role grep: `control-plane,master` → `control-plane` (modern k8s no longer shows `master` in ROLES column).
- Taint un-taint: `node-role.kubernetes.io/master-` → `node-role.kubernetes.io/control-plane-`.

### `envoy/envoy-template-2.yaml` — v2alpha → v3 API
- `envoy.config.resource_monitor.fixed_heap.v2alpha.FixedHeapConfig` → `envoy.extensions.resource_monitors.fixed_heap.v3.FixedHeapConfig`.
- Config validated OK with envoy 1.32.2.

### `envoy/install-envoy.script` — distro fallback
- Added codename mapping for distros not yet in the official repo (trixie→bookworm, noble→jammy).
- Added `--batch --yes` to gpg dirmgr to avoid `/dev/tty` warnings in non-interactive environments.

## P3 — Bug fixes (done)

### `utils.sh` — critical `is_address_local()` line-break bug
- `$addr` was split across two lines due to a missing continuation character, causing the `localhost` comparison to always fail for all LB scripts.
- All 12 call sites in envoy/haproxy/nginx install/configure/start/stop scripts updated to use `is_address_local()` instead of fragile string matching against `this_host_ip`/`this_host_name`.

### `envoy/envoy-template-2.yaml` — admin access_log
- Replaced deprecated `access_log_path` with `access_log` list format pointing to `/dev/null`.
- Fixes `Permission denied` crash when envoy runs as non-root user (uid 103) trying to write to `/tmp/admin_access.log`.

### `kube-remove.sh` — iptables, held packages, pgrep
- `iptables` not in non-root `PATH` (`/usr/sbin/iptables`) → use `command -v` to locate it at runtime.
- `apt purge -y` fails on held packages → added `--allow-change-held-packages`.
- `pgrep kube-controller-manager` fails (process name >15 chars) → use `pgrep -f` for full command match.

### `tests/e2e-single-node.sh` — rewritten
- Uses `bash -c ". script.sh"` per-step to isolate sourced scripts and prevent exit-code leaks.
- Added `step()` helper function with structured error reporting.
- Verified: full single-node cluster (envoy LB → kubeadm init → Calico → nginx demo) passes end-to-end.

### `nginx/install-nginx.sh` — official nginx.org repository
- Switched from Debian apt (`nginx 1.26.3`) to official nginx.org repo (`nginx 1.30.3`).
- Same pattern as envoy: `signed-by` GPG keyring, distro fallback mapping (trixie→bookworm, noble→jammy).
- Verifies `nginx.org` origin before skipping reinstall.

### `nginx/configure-nginx.sh` — sudo + backends fix
- `mv nginx.draft /etc/nginx/nginx.conf` → `sudo cp` (permission denied when running as non-root).
- `echo "" >/tmp/backends.txt` caused leading blank line that broke stream block indentation → built `backends` string via variable.

### `haproxy/configure-haproxy.sh` — sudo fix
- `mv haproxy.draft /etc/haproxy/haproxy.cfg` → `sudo cp` (same permission denied bug as nginx).

### `haproxy/start-haproxy.sh` — sysctl redirect fix
- `sudo echo 'net.ipv4.ip_nonlocal_bind=1' >>/etc/sysctl.conf` doesn't work (redirection runs as user, not root) → `echo ... | sudo tee -a`.

## P4 — Complete teardown (done)

### `kube-remove.sh` — expanded cleanup
- Removes Kubernetes apt repo (`/etc/apt/sources.list.d/kubernetes.list`), GPG keyring, and apt pin on every node.
- Removes k8s sysctl and modules-load configs (`/etc/sysctl.d/k8s.conf`, `/etc/modules-load.d/k8s.conf`).
- Changed `rm -rf /etc/cni/net.d` → `rm -rf /etc/cni` to cover all CNI artifacts.

### `cleanup-all.sh` — new full-teardown script
- One-shot nuclear option: LB + k8s + repos + keyrings + temp files.
- Stops and purges haproxy/nginx/envoy (detects which is installed).
- Removes LB-specific apt repos and GPG keyrings (nginx.org, apt.envoyproxy.io).
- Sources `kube-remove.sh` for k8s teardown, then `clean-trash.sh` for temp files.
- Handles remote LB cleanup via SSH (same `is_address_local`/`remote_cmd` pattern as install).
- Falls back to scanning all three LBs if no LB is configured in `setup.conf`.
- Prints reminder to run `kube-remove.sh` on each remote worker/master.

### Verification
- All three LB types (envoy, nginx, haproxy) tested end-to-end on single-node cluster.
- Each passes: LB install → kubeadm init → Calico CNI → nginx demo deployment.

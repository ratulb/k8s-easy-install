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

### `cluster.sh` — deterministic menu ordering
- Replaced `declare -A` associative array (non-deterministic, varies by bash version) with indexed array `menu_items`.
- Menu items fixed: 1) Cluster setup, 2) Kubelet status, 3) System pod status, 4) LB status, 5) Console, 6) !! Full cleanup, 7) Refresh, 8) Quit.

### `envoy/configure-envoy.sh`, `haproxy/configure-haproxy.sh` — removed shared temp file
- `/tmp/backends.txt` was shared between envoy and haproxy config scripts; saved from one run could corrupt the other.
- Both now build backend strings in-memory via variable and append directly to draft file.

## P5 — Multi-node bug fixes (done)

### `prepare-cluster-join.sh` — rewritten (P0)
- Old code used `tail -2` which captured the wrong lines and prepended `sudo` to the prompt text.
- New code: uses `awk` to reassemble continuation lines (kubeadm outputs multi-line commands with `\` continuations), then differentiates worker vs control-plane by `--control-plane` flag.
- Handles missing log file, missing join commands, and missing `--control-plane` (single-master without `--upload-certs`).

### `haproxy/start-haproxy.sh` — remote sysctl redirect (P0)
- `remote_cmd $lb echo '...' >>/etc/sysctl.conf` — the `>>` redirect runs on the controller, not the remote LB.
- Fixed: `remote_cmd $lb "echo '...' | sudo tee -a /etc/sysctl.conf"`.

### `copy-kube-config.sh` — remote sed/echo redirects (P0)
- Two bugs: `$HOME/.bashrc` expanded on controller (wrong path on remote), and `>>` redirect ran on controller.
- Fixed: use `~/.bashrc` inside quoted remote command strings for both the `sed -i` removal and the `echo` append.

### `launch-cluster.sh`, `e2e-single-node.sh` — sed delimiter collision (P0)
- `s/#pod_network_cidr#/$pod_network_cidr/g` used `/` delimiter, but CIDR value contains `/` (e.g., `10.244.0.0/16`).
- Fixed: use `|` as sed delimiter: `s|#pod_network_cidr#|$pod_network_cidr|g`.

### `tests/test.sh` — invalid sed flag (P1)
- `s/lb_type=.*/lb_type=$_lb/go` — `/go` is not a valid sed flag combination.
- Fixed: removed spurious `/go` flags.

### `system-pod-status.sh` — broken while-condition (P1)
- `while [ "$i" ] >0 && [[ ! "$status" = "Running" ]]` — `>0` creates a file named `0` instead of comparing.
- Fixed: `while [[ "$i" -gt 0 && "$status" != "Running" ]]`.

### `nginx-deployment.yaml` — stale taint key (P1)
- `node-role.kubernetes.io/master` → `node-role.kubernetes.io/control-plane`.

### `utils.sh` — duplicate code in `configure_multi_master_setup()` (P1)
- The LB config sed block (lines 290-296) was an exact duplicate of lines 272-278. Removed.

### `launch-cluster.sh` — stale "weave" print (P1)
- `prnt "Installing weave cni pluggin"` → `prnt "Installing Calico CNI"`.

### Verification
- All three LB types (envoy, nginx, haproxy) tested end-to-end on single-node cluster.
- Each passes: LB install → kubeadm init → Calico CNI → nginx demo deployment.
- `prepare-cluster-join.sh` verified with mock kubeadm-init.log (multi-line join commands with `\` continuations).

# k8s-easy-install — AGENTS.md

## Entrypoint & invocation
- `./cluster.sh` — interactive menu-driven installer. Must run as root/with sudo.
- No build system, package manager, or test framework. Pure bash scripts sourced at runtime via `. script.sh`.
- `utils.sh` auto-calls `read_setup` on source (line 23), so sourcing it immediately reads `setup.conf`.

## Configuration
- `setup.conf` — key-value config (masters, workers, loadbalancer, lb_type, lb_port, pod_network_cidr).
- Interactive menu writes selections to `/tmp/lb_addr_and_port.txt`, `/tmp/selected_lb_type.txt`, `/tmp/master-ips-cluster-setup.txt`, `/tmp/worker-ips-cluster-setup.txt`, then `configure_multi_master_setup()` syncs them into `setup.conf`.

## Architecture
- **Controller machine** runs `cluster.sh`; SSH public key must be in `~/.ssh/authorized_keys` of every remote node.
- **Load balancer** (haproxy/nginx/envoy) installed first, then master nodes (first master runs `kubeadm init`), then workers join.
- **Single-node**: LB on localhost with port != 6443 (e.g., 6643). Sequence: LB → Master → Launch (skip workers, just press 'y').
- **Multi-node LB** on control machine: choose a port > 1000 so it doesn't conflict with kube-apiserver (6443).

## Key files
| File | Role |
|------|------|
| `cluster.sh` | Interactive menu |
| `launch-cluster.sh` | Orchestrator: checks connectivity, runs install scripts in order on each node |
| `kube-remove.sh` | Destroys existing k8s installation (always runs before install); also removes k8s apt repo, keyring, pin, sysctl, and modules configs |
| `cleanup-all.sh` | Full teardown: stops/purges LB, removes LB repos/keyrings, sources kube-remove.sh + clean-trash.sh |
| `cluster.sh` | Main menu includes `!! Full cleanup` option that sources cleanup-all.sh with a danger warning |
| `install-kubeadm.sh` | Installs kubeadm/kubelet/kubectl via apt |
| `install-docker.sh` | No-op — Docker is no longer used. Kubernetes uses containerd directly. |
| `kubeadm-init.sh` | Template — `#masters#`, `#lb_port#`, `#loadbalancer#`, `#pod_network_cidr#` replaced by `sed` at runtime |
| `prepare-cluster-join.sh` | Extracts join commands from `kubeadm-init.log` |
| `install-cni-pluggin.sh` | Installs Calico CNI (note typo in filename) |
| `init-self.sh` | Sets up `kubectl` on the controller machine |
| `test-commands.sh` | Post-install validation + deploys test nginx pod |
| `clean-trash.sh` | Removes generated temp files (unless `$debug` is set) |
| `haproxy/`, `nginx/`, `envoy/` | LB-specific install/configure/start/stop scripts |

## Remote execution
- `remote_script <host> <file>` — runs a local script on a remote host via SSH stdin.
- `remote_cmd <host> <args>` — runs a command on a remote host.
- `remote_copy <src> <dst>` — SCP with `StrictHostKeyChecking=no`.

## Tests
- `tests/test.sh` — runs `launch-cluster.sh` in a loop (default 20 iterations) with random LB types. Outputs to `tests/test-result.txt`.
- Run: `bash tests/test.sh [count]`

## Gotchas
- `utils.sh` must be sourced with `. utils.sh` (not `source utils.sh` — but both work in bash). Scripts use `.` form.
- `kubeadm-init.sh` is copied to `kubeadm-init.sh.tmp` then placeholders replaced with sed. The `.tmp` file is sourced as a script (not executed).
- `$debug` env var suppresses temp file cleanup and enables debug print via `debug()`.
- Weave CNI is hardcoded in `install-cni-pluggin.sh` — no flannel/calico option.
- `kube-remove.sh` does aggressive cleanup (iptables flush, process kill, apt purge) — safe to run repeatedly.
- `console.sh` drops into interactive bash within the menu (`exit` to return).
- Controller machine not part of cluster: `init-self.sh` downloads `kubectl` binary and copies kubeconfig from first master.

## Change log
Changes made during the 2026 revival are tracked in [`CHANGES.md`](./CHANGES.md).

## Stale / needs update (revival project)

This project has not been maintained in years. The following items have been fixed to target v1.36 on modern OS:
- ✅ **`install-kubeadm.sh`** — updated to `pkgs.k8s.io` repo (v1.36), gpg `signed-by` format, containerd CRI config with `SystemdCgroup`, module loading, removes Docker if present.
- ✅ **`install-cni-pluggin.sh`** — replaced Weave (archived) with Calico v3.32.1.
- ✅ **`install-docker.sh`** — no-op; Docker is unused (containerd is the runtime).
- ✅ **`install-kubeadm.sh`** now includes containerd config reset, so Docker-hostile containerd configs (`disabled_plugins = ["cri"]`) are fixed.
- ✅ **`envoy/install-envoy.script`** — uses official `apt.envoyproxy.io` repo with `signed-by` key, distro codename fallback mapping.
- ✅ **`kube-remove.sh`** — added containerd reset (stop, rm data, regenerate config, `SystemdCgroup`, restart).
- ✅ **`test-commands.sh`** — taint label → `node-role.kubernetes.io/control-plane`, role grep → `control-plane`.
- ✅ **`envoy/envoy-template-2.yaml`** — fixed `v2alpha.FixedHeapConfig` → `v3.FixedHeapConfig` (validated with envoy 1.32.2).
- ✅ **`nginx/install-nginx.sh`** — switched from Debian apt to official `nginx.org` repo with `signed-by` key, distro fallback mapping.
- ✅ **`kube-remove.sh`** — fixed `iptables` PATH, `--allow-change-held-packages`, `pgrep -f`.
- ✅ **`tests/e2e-single-node.sh`** — rewritten with per-step `bash -c` isolation and `step()` error handler.
- ✅ **`envoy/envoy-template-2.yaml`** — `access_log_path`→`access_log` list format (fixes non-root Permission denied).
- ✅ **`utils.sh`** — `is_address_local()` line-break bug fixed; all 12 LB call sites updated.
- ✅ **`nginx/configure-nginx.sh`** — fixed `mv` permission denied (no sudo), fixed backends indentation.
- ✅ **`haproxy/configure-haproxy.sh`** — fixed `mv` permission denied (no sudo).
- ✅ **`haproxy/start-haproxy.sh`** — fixed `sudo echo >>` (redirection not root) → `sudo tee -a`.
- ✅ **All three LBs verified** — envoy, nginx, and haproxy each pass end-to-end single-node test.
- ✅ **`kube-remove.sh`** — expanded: removes k8s apt repo, keyring, pin, sysctl, modules-load configs; `/etc/cni/net.d`→`/etc/cni`.
- ✅ **`cleanup-all.sh`** — new full-teardown script: stops/purges all LBs, removes LB repos/keyrings, runs kube-remove.sh + clean-trash.sh.

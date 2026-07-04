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
| `kube-remove.sh` | Destroys existing k8s installation (always runs before install) |
| `install-kubeadm.sh` | Installs kubeadm/kubelet/kubectl via apt |
| `install-docker.sh` | Docker CE install (commented out in `launch-cluster.sh`) |
| `kubeadm-init.sh` | Template — `#masters#`, `#lb_port#`, `#loadbalancer#`, `#pod_network_cidr#` replaced by `sed` at runtime |
| `prepare-cluster-join.sh` | Extracts join commands from `kubeadm-init.log` |
| `install-cni-pluggin.sh` | Installs Weave CNI (note typo in filename) |
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

## Stale / needs update (revival project)

This project has not been maintained in years. Everything is stale — Kubernetes, load balancers, Weave CNI — and will likely fail on modern OS releases. When reviving:
- **`kubeadm-init.sh`** — `--token-ttl 0` is deprecated; kubeadm now generates non-expiring tokens by default. `--upload-certs` flag may need verification.
- **`install-kubeadm.sh`** — uses the old `apt.kubernetes.io` repo (moved to `pkgs.k8s.io`). Keyring format has changed.
- **`install-docker.sh`** — Docker no longer uses apt-key; add-apt-repository URLs are years out of date (Ubuntu eoan references).
- **`install-cni-pluggin.sh`** — Weave has been archived upstream. Replace with Cilium, Calico, or Flannel.
- **`envoy/`** — `.install-envoy.script` references very old envoy version.
- **`kube-remove.sh`** — `kubeadm reset --force` + apt purge still works but may need `containerd` reset step.
- **Kubernetes itself** — tested on v1.19–1.23 era. kubeadm config is the legacy v1beta2 API.

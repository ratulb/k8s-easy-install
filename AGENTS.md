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
- `kube-remove.sh` does aggressive cleanup (iptables flush, process kill, apt purge) — safe to run repeatedly.
- `console.sh` drops into interactive bash within the menu (`exit` to return).
- Controller machine not part of cluster: `init-self.sh` downloads `kubectl` binary and copies kubeconfig from first master.

## Change log
All changes made during the 2026 revival are tracked in [`CHANGES.md`](./CHANGES.md).

## Milestone status

### ✅ Milestone 1: Single-node revival (complete)
The project now works on a single node with all three LB types:
- Kubernetes v1.36.2 from `pkgs.k8s.io`, Calico CNI v3.32.1, containerd CRI
- Three LBs (haproxy, nginx, envoy) each verified end-to-end
- `cleanup-all.sh` for full nuclear teardown
- Deterministic menu ordering, no shared temp files, proper `sudo tee -a` redirection

### 🔜 Milestone 2: Multi-node provisioning (next)
All script-level bugs that block multi-node have been fixed:

| Area | Status | Detail |
|------|--------|--------|
| `prepare-cluster-join.sh` | ✅ | Rewritten: awk-based join command extraction handles `\` continuation lines, correctly differentiates worker vs control-plane by `--control-plane` flag |
| `haproxy/start-haproxy.sh` | ✅ | Remote sysctl redirect fixed: `>>/etc/sysctl.conf` now runs on remote host via `sudo tee -a` |
| `copy-kube-config.sh` | ✅ | Remote `$HOME/.bashrc` sed/echo redirects fixed: all commands quoted and use `~/.bashrc` |
| `launch-cluster.sh:63` | ✅ | sed delimiter `/` → `\|` to avoid CIDR collision (`10.244.0.0/16`) |
| Remote execution pattern | ✅ | All 3 scripts with `>>` redirect bugs resolved |
| **Remaining** | ⏳ | Needs a second physical host to test: remote join, cert copy, worker/control-plane join flow, cleanup-all.sh remote iteration |
| **Tests** | ⏳ | `tests/test.sh` runs `launch-cluster.sh` in a loop with random LB types — needs real multi-node env |

Pre-requisites for multi-node testing:
- Controller SSH key in `~/.ssh/authorized_keys` on every remote node
- Root/sudo access on all remote nodes
- Network connectivity between all nodes

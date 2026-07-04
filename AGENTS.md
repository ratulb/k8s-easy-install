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
- `tests/e2e-single-node.sh` — single-node end-to-end test (LB → install → init → Calico → test).
- `tests/e2e-multi-node.sh [iterations]` — multi-node end-to-end test: builds cluster, runs cross-node pod networking test (HTTP both ways between nodes), tears down. Repeats per iteration.

## Gotchas
- `utils.sh` must be sourced with `. utils.sh` (not `source utils.sh` — but both work in bash). Scripts use `.` form.
- `kubeadm-init.sh` is copied to `kubeadm-init.sh.tmp` then placeholders replaced with sed. The `.tmp` file is sourced as a script (not executed).
- `$debug` env var suppresses temp file cleanup and enables debug print via `debug()`.
- `kube-remove.sh` does aggressive cleanup (iptables flush, process kill, apt purge) — safe to run repeatedly.
- `console.sh` drops into interactive bash within the menu (`exit` to return).
- Controller machine can be the first master (if `masters=localhost`) or a separate machine: `init-self.sh` downloads `kubectl` binary and copies kubeconfig from first master.
- `install-kubeadm.sh` now installs containerd if not already present (fix for bare Ubuntu systems without Docker history).

## Change log
All changes made during the 2026 revival are tracked in [`CHANGES.md`](./CHANGES.md).

## Milestone status

### ✅ Milestone 1: Single-node revival (complete)
The project now works on a single node with all three LB types:
- **Tested OS**: Debian 13.5 (trixie), kernel 6.12.94, x86_64
- **Kubernetes**: v1.36.2 from `pkgs.k8s.io`, containerd v2.2.5 (CRI), Calico CNI v3.32.1
- **Load balancers**: haproxy 3.0.11 (Debian apt), nginx 1.30.3 (nginx.org), envoy 1.32.2 (apt.envoyproxy.io)
- `cleanup-all.sh` for full nuclear teardown (also removes envoy's manually-installed systemd unit)
- Deterministic menu ordering, no shared temp files, proper `sudo tee -a` redirection

### ✅ Milestone 2: Multi-node provisioning (complete)
Multi-node cluster deployed and verified with two physical hosts:

| Host | Role | OS | IP | Kubernetes |
|------|------|----|----|------------|
| vm | Control-plane + LB | Debian 13.5 (trixie) | 10.160.0.7 | v1.36.2, containerd v2.2.5 |
| box | Worker | Ubuntu 22.04.5 (jammy) | 10.160.0.8 | v1.36.2, containerd v2.2.1 |

**Tested**: haproxy LB → kubeadm init → worker join → Calico CNI on all nodes → nginx deployment.
**Remaining issue**: All nginx pods landed on control-plane (vm). Worker node needs pods scheduled to it for cross-node networking test.

**Fix discovered**: `install-kubeadm.sh` needed containerd installation on fresh Ubuntu systems.

### ✅ Milestone 3: Cross-node pod networking (complete)
Cross-node pod communication verified in both directions using Calico VXLAN:
- Default Calico uses IPIP (`ipipMode: Always`) but IPIP is blocked by most clouds.
- `install-cni-pluggin.sh` now modifies the manifest to use VXLAN before applying:
  `CALICO_IPV4POOL_IPIP`: `"Always"` → `"Never"`
  `CALICO_IPV4POOL_VXLAN`: `"Never"` → `"Always"`
- VXLAN tunnel (`vxlan.calico`) routes show bidirectional pod traffic between nodes.
- `launch-cluster.sh` full automated pipeline validated end-to-end from scratch.

### ✅ Milestone 4: Multi-node test automation (complete)
- `tests/e2e-multi-node.sh` automates the full cycle: build → cross-node pod networking test → teardown.
- Verified: passes 1/1 iteration (build, bidirectional HTTP, cleanup).

### 🔜 Milestone 5: Multi-master HA (next)
- Set up a second control-plane node (HA masters).
- Update `tests/test.sh` to run `cleanup-all.sh` between iterations.

Pre-requisites for multi-node testing:
- Controller SSH key in `~/.ssh/authorized_keys` on every remote node
- Root/sudo access on all remote nodes
- Network connectivity between all nodes
- Consistent username across all nodes

# ABOUT.md — k8s-easy-install

## Overview
**k8s-easy-install** is a pure-Bash, menu-driven tool for provisioning single-node or multi-node Kubernetes clusters from a controller machine over SSH. It avoids Ansible/Terraform/cloud-console workflows and orchestrates install, configuration, join, and smoke testing through shell scripts.

- **Entrypoint:** `sudo ./cluster.sh`
- **Model:** controller runs scripts remotely via SSH (`remote_script`, `remote_cmd`, `remote_copy` in `utils.sh`) with `StrictHostKeyChecking=no`
- **No build/test framework or package manager:** scripts are sourced/executed directly with Bash

## Quick facts
| Area | Details |
|---|---|
| Cluster modes | Single-node and multi-node (control-plane + workers) |
| Load balancers | HAProxy, NGINX, or Envoy (TCP proxy to kube-apiserver :6443) |
| CNI | Calico v3.32.1 (patched to VXLAN mode) |
| Kubernetes | v1.37.x repo (`pkgs.k8s.io ... v1.37`) — kubelet/kubeadm/kubectl installed and held |
| Container runtime | containerd (configured with `SystemdCgroup = true`; Docker removed if present) |
| Target OS (per README) | Debian 11/12/13, Ubuntu 20.04/22.04/24.04 |
| Config file | `setup.conf` (key=value), editable directly or via menu |

## Architecture and execution flow

### High-level flow (`launch-cluster.sh`)
1. **Preflight/validation**: checks master/LB config completeness, SSH/connectivity to LB/masters/workers, and prints planned configuration.
2. **Template rendering**: copies `kubeadm-init.sh` → `kubeadm-init.sh.tmp` and replaces placeholders:
   - `#masters#` → masters list
   - `#lb_port#` → LB port
   - `#loadbalancer#` → LB address
   - `#pod_network_cidr#` → pod CIDR
3. **Load balancer setup** (if configured): installs, configures, and starts selected LB (`haproxy/`, `nginx/`, or `envoy/` scripts).
4. **Per master node**: runs `kube-remove.sh` then `install-kubeadm.sh`.
   - **First master:** sources `kubeadm-init.sh.tmp`, extracts join commands via `prepare-cluster-join.sh`, installs CNI via `install-cni-pluggin.sh`.
   - **Additional masters:** runs generated `master-join-cluster.cmd`.
   - For remote first master, fetches init log/kubeconfig as needed (`copy-init-log.sh`, `copy-kube-config.sh`).
5. **Per worker node**: runs `kube-remove.sh`, `install-kubeadm.sh`, then `worker-join-cluster.cmd`.
6. **Controller bootstrap:** `init-self.sh` installs/configures `kubectl` and kubeconfig on controller when needed.
7. **Smoke test:** `test-commands.sh` waits for nodes Ready, removes control-plane taint, deploys test nginx workload.
8. **Cleanup:** `clean-trash.sh` removes temp artifacts (unless debug mode preserves them).

### Remote execution model (`utils.sh`)
- `remote_script <host> <local-file>`: runs a local script on remote host via SSH stdin.
- `remote_cmd <host> <args...>`: runs a command remotely.
- `remote_copy <src> <dst>`: SCP with strict host key checking disabled.
- `is_address_local()` detects local targets via local IP/hostname/public IP/SSH-hostname fallback; `can_access_address()` validates reachability.
- Sourcing `utils.sh` auto-calls `read_setup`, loading `setup.conf` into environment variables.

## Menu and configuration (`cluster.sh`, `setup.conf`)

### Interactive menu (`sudo ./cluster.sh`)
Main options include: Cluster setup, Kubelet status, System pod status, Load balancer status, Console, Full cleanup, Refresh, Quit.

**Cluster setup flow** writes selections to temp files, then syncs to `setup.conf`:
- Load balancer address/port → `/tmp/lb_addr_and_port.txt`
- Load balancer type → `/tmp/selected_lb_type.txt`
- Master nodes → `/tmp/master-ips-cluster-setup.txt`
- Worker nodes → `/tmp/worker-ips-cluster-setup.txt`
- `Launch` validates configuration (`validate_multi-master-configuration`, completeness checks) and runs `launch-cluster.sh`

### `setup.conf` keys
| Key | Purpose / example |
|---|---|
| `masters` | Space-separated master hosts/IPs (e.g. `10.1.0.4 10.3.0.4`) |
| `workers` | Space-separated worker hosts/IPs (empty for single-node/control-plane-only workloads) |
| `loadbalancer` | LB host/IP |
| `lb_type` | `haproxy`, `nginx`, or `envoy` |
| `lb_port` | LB listen port (must not be `6443` when LB collides with a master on same host) |
| `pod_network_cidr` | Pod CIDR passed to `kubeadm init --pod-network-cidr` (e.g. `192.168.0.0/16`) |
| `sleep_time` | Retry/wait interval used by scripts |
| `cri_containerd_cni_ver` | Present in config (informational in current flow) |

## Key scripts and responsibilities

| File | Role |
|---|---|
| `cluster.sh` | Interactive menu/UX, config capture, validation, launch/cleanup entrypoints |
| `launch-cluster.sh` | Main orchestrator for LB install, node provisioning, init/join, CNI, controller setup, smoke test |
| `utils.sh` | Shared helpers (logging, SSH/remote ops, IP/host/port validation, local-address detection, config read/write/reset) |
| `install-kubeadm.sh` | Prepares node: kernel modules/sysctl, removes Docker, installs/configures containerd, adds K8s apt repo/key/pin (v1.37), installs & holds kubeadm/kubelet/kubectl, sets kubelet node IP |
| `kubeadm-init.sh` | Template for first control-plane init; renders endpoint/pod CIDR/advertise address, runs `kubeadm init`, writes kubeconfig and bash completion |
| `prepare-cluster-join.sh` | Parses `kubeadm-init.log` into `worker-join-cluster.cmd` and `master-join-cluster.cmd` (handles multi-line join commands) |
| `install-cni-pluggin.sh` | Downloads Calico v3.32.1 manifest, patches IPIP→Never and VXLAN→Always, sets vxlan backend/readiness/env, applies manifest (filename intentionally spelled `pluggin`) |
| `kube-remove.sh` | Full node Kubernetes teardown/reset (kubeadm reset, purge packages/repos/config/data, flush iptables, reset containerd, kill orphan processes); safe to re-run before install |
| `cleanup-all.sh` | Full cluster/system cleanup: LB removal (local/remote), local + remote Kubernetes cleanup, temp file removal, apt refresh |
| `init-self.sh` | Installs `kubectl` on controller if needed and copies kubeconfig from local/first remote master into controller user's `~/.kube/config` |
| `copy-kube-config.sh` / `copy-init-log.sh` | Helpers to transfer kubeconfig and `kubeadm-init.log` between controller and remote masters |
| `test-commands.sh` | Post-install smoke test: node readiness wait, remove control-plane taint, deploy nginx from remote GitHub manifest, wait for pod Running |
| `console.sh` | Opens an interactive bash shell from menu |
| `confirm-action.sh` | Reusable confirmation prompt helper |
| `clean-trash.sh` | Removes generated/temp files |
| `install-docker.sh` | Legacy/no-op in current flow (Docker is removed in favor of containerd) |

## Load balancers
Located in `haproxy/`, `nginx/`, `envoy/` with consistent `install`, `configure`, `start`, `stop` scripts.

| Type | Install source | Config target | Notes |
|---|---|---|---|
| HAProxy | distro apt packages | `/etc/haproxy/haproxy.cfg` | Generates TCP frontend/backend with master servers on :6443; enables nonlocal bind; stops other LB types on start |
| NGINX | official nginx.org apt repo (codename fallback logic) | `/etc/nginx/nginx.conf` (stream block appended/rendered) | TCP stream upstream to masters:6443 |
| Envoy | `apt.envoyproxy.io` repo | rendered from `envoy-template-*.yaml` + systemd service | Installed/configured via Envoy-specific scripts and service management |

All LBs act as TCP reverse proxies in front of control-plane API servers. In single-node/same-host scenarios, LB port must differ from `6443`.

## CNI and networking
- **Calico v3.32.1** installed from upstream manifest (`install-cni-pluggin.sh`).
- Manifest is patched for cloud-friendly overlay networking:
  - `CALICO_IPV4POOL_IPIP`: `Always` → `Never`
  - `CALICO_IPV4POOL_VXLAN`: `Never` → `Always`
  - backend set to `vxlan`; readiness adjusted for non-BIRD mode
  - `IP_AUTODETECTION_METHOD=kubernetes-internal-ip`
- **Cross-node pod networking** relies on VXLAN (UDP 4789); README notes BGP/TCP 179 considerations in some environments/firewall setups.

## Tests (`tests/`)

| Script | Purpose | Behavior highlights |
|---|---|---|
| `e2e-single-node.sh [lb_type]` | Fast single-node regression of install pipeline | Rewrites `setup.conf` for localhost LB/master, runs stepwise install/init/CNI/smoke flow; **leaves cluster running** |
| `e2e-multi-node.sh [iterations]` | Multi-node build + cross-node networking validation | Uses existing multi-node `setup.conf`; runs `launch-cluster.sh`, deploys node-pinned nginx/busybox pods, verifies HTTP both directions, then `cleanup-all.sh` per iteration |
| `test.sh [count]` | Stress/repeatability test | Random LB type per iteration, launches cluster, captures `kubectl get nodes` to `tests/test-result.txt`; **no cleanup between iterations** (known limitation) |

## Prerequisites and notable gotchas
- **Access requirements:** controller must have SSH key access to all remote nodes; passwordless sudo required on nodes; consistent SSH user recommended.
- **Networking/firewall:** nodes must reach each other for Kubernetes/LB traffic; VXLAN UDP 4789 required for pod networking (and README notes TCP 179/BGP-related cases). Public IPs may be needed when private ranges collide across networks.
- **Single-node LB port:** cannot use `6443` on same host as kube-apiserver (use e.g. 6643/7443/9999).
- **Idempotent-ish rebuilds:** `kube-remove.sh` performs aggressive cleanup and runs before installs; re-running after failures is expected workflow. Full teardown via menu option 6 or `cleanup-all.sh`.
- **Controller kubectl:** may be installed as standalone binary and configured from first master's kubeconfig (`init-self.sh`), depending on whether controller is part of cluster nodes.
- **Smoke test dependency:** `test-commands.sh` applies an nginx manifest from a remote GitHub URL (requires internet access).
- **Generated artifacts:** rendered/join/log/temp files are produced during runs (e.g. `kubeadm-init.sh.tmp`, join command files, logs); `clean-trash.sh`/`.gitignore` manage them. Use `debug=yes sudo ./cluster.sh` to preserve debug artifacts.
- **Naming quirks/legacy:** `install-cni-pluggin.sh` filename typo is intentional; `install-docker.sh` is legacy/no-op. For full historical changes see `CHANGES.md`.
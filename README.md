# k8s-easy-install

**Spin up a production-style Kubernetes cluster from one machine — no Ansible, no clicking around in cloud consoles, no logging into each node individually. All just from a shell-menu**


<img width="945" height="464" alt="image" src="https://github.com/user-attachments/assets/0e727bcd-7801-428c-a69e-46686fd7e0f6" />






| What | Value |
|---|---|
| Nodes | Single-node or multi-node (control-plane + workers) |
| LB options | HAProxy, NGINX, or Envoy |
| CNI | Calico (VXLAN — works in all clouds) |
| K8s version | v1.36.2 (from pkgs.k8s.io) |
| Runtime | containerd (Docker removed if present) |
| Controller | Any Linux machine with SSH access to nodes |
| Tested on | Debian 11/12/13, Ubuntu 20.04/22.04/24.04 |

---

## Quick start

```bash
git clone https://github.com/ratulb/k8s-easy-install.git
cd k8s-easy-install
sudo ./cluster.sh
```

<details>
<summary><b>Single-node cluster (all on one machine)</b></summary>

1. **Loadbalancer** — enter `localhost:9999` (port must **not** be 6443).
2. Choose a load balancer type (`haproxy` / `nginx` / `envoy`).
3. **Master nodes** — enter the local machine's IP or hostname, then a blank line.
4. **Worker nodes** — press Enter (blank line) to skip.
5. **Launch** — press `y` (single keystroke, not Enter-then-y).

After 2–3 minutes you'll have a running single-node cluster with `kubectl` on the controller.

</details>

<details>
<summary><b>Multi-node cluster (separate machines)</b></summary>

1. **Loadbalancer** — enter the LB IP and a port > 1000 (e.g. `10.0.0.10:7443`).
2. Choose a load balancer type.
3. **Master nodes** — enter hostnames or IPs, one per line, blank line to finish.
4. **Worker nodes** — same pattern.
5. **Launch** — press `y`.

The script will SSH into each node, install prerequisites, initialise the cluster, join workers, deploy Calico, and configure `kubectl` on the controller — zero manual steps beyond the initial menu.

</details>

---

## Prerequisites

### Before you begin

Check every item below. Missing any one of them will cause the install to fail.

<details>
<summary><b>1. SSH key access to all remote nodes</b></summary>

The controller's public SSH key must be in `~/.ssh/authorized_keys` on **every** remote node (LB, master, worker).

```bash
ssh-copy-id <user>@<node-ip>
# or manually append ~/.ssh/id_ed25519.pub to remote ~/.ssh/authorized_keys
```

Verify before launching:

```bash
ssh -o StrictHostKeyChecking=no <user>@<node-ip> whoami
```

</details>

<details>
<summary><b>2. Passwordless sudo on all remote nodes</b></summary>

The SSH user must be able to run `sudo` without a password prompt on every node:

```bash
echo '<username> ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/<username>
```

</details>

<details>
<summary><b>3. Consistent SSH username</b></summary>

The SSH user should be the same on the controller and all remote nodes. (If not, configure `~/.ssh/config` with `User` directives.)

</details>

<details>
<summary><b>4. Network connectivity</b></summary>

- All nodes must be able to reach each other on the ports used by Kubernetes and the LB.
- The controller must be able to SSH into every node (ports 22, 6443, and the chosen LB port).
- Workers need to reach the LB port and the control-plane.
- Cloud firewalls / security groups must allow **VXLAN (UDP 4789)** traffic between nodes for pod networking (Calico uses VXLAN, not IPIP).

</details>

<details>
<summary><b>5. Supported operating systems</b></summary>

| OS | Status |
|---|---|
| Debian 13 (trixie) | ✅ Primary target, fully tested |
| Debian 12 (bookworm) | ✅ Should work (codename fallback) |
| Debian 11 (bullseye) | ✅ Should work |
| Ubuntu 24.04 (noble) | ✅ Should work (codename fallback) |
| Ubuntu 22.04 (jammy) | ✅ Fully tested |
| Ubuntu 20.04 (focal) | ✅ Should work |

</details>

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Controller                        │
│  Runs cluster.sh  ──────SSH──────►  LB (haproxy/    │
│  (interactive menu)                nginx/envoy)     │
│                                     │               │
│                   ┌─────────────────┼──────────┐    │
│                   ▼                 ▼          ▼    │
│              Master 1           Master 2..N   Worker│
│            (kubeadm init)       (join)       (join) │
│              │                                      │
│              └──► kubectl config (copied back)      │
└─────────────────────────────────────────────────────┘
```

The controller machine is **not** automatically joined to the cluster. `kubectl` is installed as a standalone binary and configured via kubeconfig copied from the first master. The controller can be the same machine as the first master (set `masters=localhost`), or a completely separate machine.

---

## What happens when you launch

`launch-cluster.sh` orchestrates every step in order:

```
 1.  Validate SSH connectivity to every node (LB, masters, workers)
 2.  Install & configure the chosen load balancer on the LB node
 3.  For every master:
       kube-remove.sh       — nuke any existing k8s installation
       install-kubeadm.sh   — install kubelet / kubeadm / kubectl via apt
 4.  First master only:
       kubeadm-init.sh.tmp  — template rendered with real values
       prepare-cluster-join.sh  — extract join commands from log
       install-cni-pluggin.sh   — deploy Calico CNI (VXLAN mode)
 5.  Remaining masters:
       master-join-cluster.cmd
 6.  Workers:
       worker-join-cluster.cmd
 7.  init-self.sh           — download kubectl, copy kubeconfig to controller
 8.  test-commands.sh       — smoke test: deploy nginx, wait for pods
 9.  clean-trash.sh         — remove temp files (unless $debug is set)
```

<details>
<summary><b>Template-based kubeadm init</b></summary>

`kubeadm-init.sh` is a template with placeholders replaced at runtime:

| Placeholder | Replaced with |
|---|---|
| `#masters#` | Space-separated master hostnames |
| `#lb_port#` | Chosen LB port |
| `#loadbalancer#` | LB hostname / IP |
| `#pod_network_cidr#` | Pod CIDR from `setup.conf` |

`launch-cluster.sh` copies it to `kubeadm-init.sh.tmp` and runs `sed` substitutions before sourcing it.

The join commands for additional masters and workers are extracted from the first master's `kubeadm-init.log` by `prepare-cluster-join.sh` (rewritten to handle multi-line kubeadm output with `\` continuations).

</details>

<details>
<summary><b>Remote execution model</b></summary>

All remote operations use three helpers from `utils.sh`:

```bash
remote_script <host> <local-file>     # Run a local script on a remote host (SSH stdin)
remote_cmd    <host> <args...>        # Run a one-shot command on a remote host
remote_copy   <src> <dst>            # SCP with StrictHostKeyChecking=no
```

There is no agent, no daemon, no configuration management tool. Everything happens via plain SSH with strict host key checking disabled (ephemeral cloud nodes).

</details>

---

## CNI provider: Calico (VXLAN)

Calico v3.32.1 is the only CNI plugin. It is installed by `install-cni-pluggin.sh`.

### Why VXLAN, not IPIP

The default Calico manifest uses **IPIP** (`ipipMode: Always`). IPIP (protocol 4) is blocked by most cloud providers, causing cross-node pod traffic to fail silently.

The install script:
1. Downloads the manifest.
2. Swaps `CALICO_IPV4POOL_IPIP` from `"Always"` to `"Never"`.
3. Swaps `CALICO_IPV4POOL_VXLAN` from `"Never"` to `"Always"`.
4. Applies the modified manifest.

VXLAN (UDP 4789) passes through all major cloud firewalls and works on bare metal.

### Cross-node pod networking verified

Both directions are validated by `tests/e2e-multi-node.sh`:
- Control-plane pod → worker pod (HTTP, `wget -qO-`)
- Worker pod → control-plane pod (HTTP, `wget -qO-`)

### To replace Calico

Replace the contents of `install-cni-pluggin.sh` with a different CNI manifest. The script is a single `kubectl apply -f` (with optional manifest patching).

---

## Load balancers

Three options, pick one in the menu:

| LB | Package source | Config | Notes |
|---|---|---|---|
| **HAProxy** | Debian/Ubuntu apt | `/etc/haproxy/haproxy.cfg` — TCP `server` lines | Simplest, smallest |
| **NGINX** | official nginx.org repo | `/etc/nginx/nginx.conf` — `stream` block | Version from nginx.org, not distro |
| **Envoy** | `apt.envoyproxy.io` | YAML template → rendered → systemd | Most configurable, heaviest |

All three are configured as TCP reverse proxies forwarding to the master's kube-apiserver port (6443). They bind to the configured LB port and distribute traffic across all masters.

### Single-node special case

On a single-node cluster (LB and master on the same machine), the LB port **must differ from 6443** to avoid port conflict with kube-apiserver. Use 6643, 7443, or any port > 1000.

---

## Menu reference

`cluster.sh` presents this menu:

| # | Option | What it does |
|---|---|---|
| 1 | **Cluster setup** | Configure LB address/port/type, master IPs, worker IPs |
| 2 | **Kubelet status** | `systemctl status kubelet` on each master |
| 3 | **System pod status** | `kubectl -n kube-system get pods` |
| 4 | **LB status** | Check LB service status on the LB node |
| 5 | **Console** | Drop into interactive bash (`exit` to return to menu) |
| 6 | **!! Full cleanup** | ⚠️ Nuclear teardown — stops LB, removes k8s, purges repos, cleans remote nodes |
| 7 | **Refresh** | Re-read config and refresh display |
| 8 | **Quit** | Exit |

### Setup flow (option 1)

```
  ┌─────────────────────────────────────────────────┐
  │  1. Enter LB address:port (e.g. localhost:6643) │
  │  2. Select LB type (haproxy/nginx/envoy)        │
  │  3. Enter master IPs (one per line, blank=done) │
  │  4. Enter worker IPs (same pattern)             │
  │  5. Review config → Press 'y' to launch         │
  └─────────────────────────────────────────────────┘
```

All inputs are written to temporary files under `/tmp/`, then `configure_multi_master_setup()` in `utils.sh` syncs them into `setup.conf`.

---

## `setup.conf` reference

| Key | Example | Purpose |
|---|---|---|
| `masters` | `m-1 m-2` | Space-separated master hostnames/IPs |
| `workers` | `w-1 w-2` | Space-separated worker hostnames/IPs (empty = single-node) |
| `loadbalancer` | `10.0.0.10` | LB hostname or IP |
| `lb_type` | `haproxy` | One of: `haproxy`, `nginx`, `envoy` |
| `lb_port` | `7443` | LB listen port (must not be 6443 on single-node) |
| `pod_network_cidr` | `192.168.0.0/16` | Pod CIDR passed to `kubeadm init --pod-network-cidr` |
| `sleep_time` | `3` | Seconds between status-check retries |
| `cri_containerd_cni_ver` | `1.3.4` | Informational — not currently used |

You can edit this file directly instead of using the menu. Re-run `./cluster.sh` and it picks up the changes.

---

## Troubleshooting

<details>
<summary><b>SSH: "is not accessible" / permission denied</b></summary>

```
$lb_address is not accessible. Has this machine's ssh key been added to $lb_address?
```

1. Verify SSH works: `ssh <user>@<ip> whoami`
2. If it prompts for a password, the SSH key isn't authorised.
3. If it says "Host key verification failed", the node was rebuilt — clear the old key with `ssh-keygen -R <ip>`.

```bash
ssh-keygen -R <remote-ip>
ssh-copy-id <user>@<remote-ip>
```

</details>

<details>
<summary><b>LB port conflicts with kube-apiserver</b></summary>

If the LB is on the same machine as a master and you use port 6443, the install fails with:

```
Loadbalancer address collides with ip $_ip yet loadbalancer port is 6443
```

Choose an LB port > 1000 that does not collide with any service (e.g. 6643 for single-node, 7443 for multi-node).

</details>

<details>
<summary><b>Pods stuck in ContainerCreating / Pending</b></summary>

1. **Calico not ready** — check Calico pods:
   ```bash
   kubectl -n kube-system get pods | grep calico
   ```
   Both calico-node pods should be `Running`. If not, check logs:
   ```bash
   kubectl -n kube-system logs -l k8s-app=calico-node
   ```

2. **Node NotReady** — Calico may still be initialising. Wait up to 30s:
   ```bash
   kubectl get nodes -w
   ```

3. **Taints** — `test-commands.sh` removes the control-plane taint. If you skip it:
   ```bash
   kubectl taint nodes --all node-role.kubernetes.io/control-plane-
   ```

4. **IPIP blocked** — If you see cross-node connectivity fail but Calico pods are running, the cluster may still be using IPIP mode. Patch to VXLAN:
   ```bash
   kubectl patch ippool default-ipv4-ippool --type merge \
     -p '{"spec":{"ipipMode":"Never","vxlanMode":"Always"}}'
   kubectl delete pod -n kube-system -l k8s-app=calico-node
   ```

</details>

<details>
<summary><b>kubelet fails to start after install</b></summary>

```bash
sudo journalctl -u kubelet --no-pager -n 50
```

Common causes:
- **Swap is on** — kubelet requires swap to be disabled. Run `sudo swapoff -a` and remove swap entries from `/etc/fstab`.
- **Cgroup driver mismatch** — containerd defaults to `systemd`. If kubelet was configured for `cgroupfs`, re-init.
- **Containerd not running** — `sudo systemctl status containerd`. On bare Ubuntu, `install-kubeadm.sh` now auto-installs containerd, but if it failed, install manually:
  ```bash
  sudo apt install -y containerd
  sudo systemctl enable --now containerd
  ```

</details>

<details>
<summary><b>Cross-node pod networking fails</b></summary>

Pod A on the control-plane cannot reach pod B on the worker (or vice versa).

1. Verify both nodes are `Ready`:
   ```bash
   kubectl get nodes
   ```

2. Check Calico is running on both:
   ```bash
   kubectl -n kube-system get pods -o wide | grep calico-node
   ```

3. Check the IP pool mode:
   ```bash
   kubectl get ippools -o yaml | grep -E "ipipMode|vxlanMode"
   ```
   Should show `ipipMode: Never, vxlanMode: Always`. If it says `ipipMode: Always`, patch it (see above).

4. Check VXLAN routes on each node:
   ```bash
   ip route | grep vxlan
   ```
   You should see routes like `192.168.x.x via 192.168.y.y dev vxlan.calico`.

5. Test from the host level:
   ```bash
   # From the control-plane host, ping a pod on the worker
   ping -c 2 <worker-pod-ip>
   ```

</details>

<details>
<summary><b>Debug mode — preserve temp files</b></summary>

```bash
debug=yes sudo ./cluster.sh
```

Preserves:
- `kubeadm-init.sh.tmp` — rendered init template
- `kubeadm-init.log` — raw init output (contains join tokens)
- `*-join-cluster.cmd` — generated join commands
- `status-report` — `kubectl get nodes` / `kubectl get pods` output

Also enables verbose `debug()` print calls throughout the scripts.

</details>

<details>
<summary><b>"Cluster may not have been setup yet"</b></summary>

`system-pod-status.sh` checks if `kubectl` is on the `PATH`. If `init-self.sh` didn't complete (e.g. network issue downloading kubectl):

```bash
# Manual kubectl install
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl

# Fetch kubeconfig from first master
scp <user>@<first-master>:~/.kube/config ~/.kube/config
```

</details>

<details>
<summary><b>Re-running after failure</b></summary>

**It is always safe to re-run.** The flow executes `kube-remove.sh` on every node before installing, which:

- `kubeadm reset --force`
- Removes `/etc/kubernetes/`, `~/.kube/`, `/var/lib/kubelet/`, `/var/lib/etcd`
- Purges kubeadm/kubelet/kubectl packages (even if held)
- Resets containerd: stop, wipe, regenerate config with `SystemdCgroup = true`, restart
- Flushes iptables rules and kills orphan apiserver/etcd processes
- Removes K8s apt repos, GPG keyrings, sysctl configs, module-load configs

Just re-launch from the menu and re-enter your configuration.

</details>

<details>
<summary><b>Clean teardown (full nuclear option)</b></summary>

Menu option 6 (`!! Full cleanup`) or run directly:

```bash
sudo bash cleanup-all.sh
```

This does everything `kube-remove.sh` does, **plus**:
- Stops and purges the installed load balancer (haproxy/nginx/envoy)
- Removes LB-specific apt repos and GPG keyrings
- Cleans remote workers and masters (SSH, automatically)
- Removes all generated temp files
- Runs `sudo apt update` to refresh package lists

The teardown is fully automated — it detects whether each node is local or remote and handles both.

</details>

---

## Script reference

| Script | Location | Purpose | When it runs |
|---|---|---|---|
| `cluster.sh` | root | Interactive menu — entrypoint | User starts here |
| `launch-cluster.sh` | root | Orchestrator — validates, installs LB, runs scripts on each node | Menu → Launch |
| `kube-remove.sh` | root | Nuke existing K8s (kubeadm reset, purge packages, reset containerd, flush iptables) | Every node before install |
| `install-kubeadm.sh` | root | Install kubelet/kubeadm/kubectl + containerd via apt, configure sysctl + modules | Every node |
| `kubeadm-init.sh` | root | Template — `#masters#`, `#lb_port#`, `#loadbalancer#`, `#pod_network_cidr#` placeholders replaced by sed | First master |
| `prepare-cluster-join.sh` | root | Extract worker + master join commands from `kubeadm-init.log` | After init |
| `install-cni-pluggin.sh` | root | Apply Calico manifest (VXLAN mode, not IPIP) | First master |
| `init-self.sh` | root | Download kubectl binary + copy kubeconfig to controller | Controller |
| `test-commands.sh` | root | Smoke test — wait for nodes Ready, remove control-plane taint, deploy nginx, wait for pods Running | Controller |
| `cleanup-all.sh` | root | Full nuclear teardown — LB + k8s + repos + remote nodes | User runs manually or via menu |
| `clean-trash.sh` | root | Remove temp files (unless `$debug` is set) | End of launch |
| `copy-kube-config.sh` | root | Sync kubeconfig between controller and remote masters | After init |
| `copy-init-log.sh` | root | Fetch `kubeadm-init.log` from a remote master | Multi-master with remote first master |
| `console.sh` | root | Interactive bash shell within the menu (`exit` to return) | Menu → Console |
| `confirm-action.sh` | root | Generic y/n prompt helper | Sourced by other scripts |
| `install-docker.sh` | root | **No-op** — Docker is removed if present; containerd is used instead | Never (legacy) |
| `utils.sh` | root | Shared helpers: `is_address_local()`, `can_access_address()`, `remote_script()`, `remote_cmd()`, `remote_copy()`, `prnt()`, `err()`, `warn()`, `read_setup()`, `configure_multi_master_setup()` | Sourced by every script |
| `haproxy/install-haproxy.sh` | `haproxy/` | Install haproxy via apt | LB node |
| `haproxy/configure-haproxy.sh` | `haproxy/` | Write `/etc/haproxy/haproxy.cfg` with master backends | LB node |
| `haproxy/start-haproxy.sh` | `haproxy/` | Enable `net.ipv4.ip_nonlocal_bind`, start/enable systemd unit | LB node |
| `haproxy/stop-haproxy.sh` | `haproxy/` | Stop + disable systemd unit | Cleanup |
| `nginx/install-nginx.sh` | `nginx/` | Install nginx from official nginx.org repo (not distro) | LB node |
| `nginx/configure-nginx.sh` | `nginx/` | Write `/etc/nginx/nginx.conf` with `stream {}` backends | LB node |
| `nginx/start-nginx.sh` | `nginx/` | Start/enable systemd unit | LB node |
| `nginx/stop-nginx.sh` | `nginx/` | Stop + disable systemd unit | Cleanup |
| `envoy/install-envoy.sh` | `envoy/` | Install envoy from official `apt.envoyproxy.io` repo | LB node |
| `envoy/configure-envoy.sh` | `envoy/` | Render envoy YAML templates → write config | LB node |
| `envoy/start-envoy.sh` | `envoy/` | Start/enable systemd unit | LB node |
| `envoy/stop-envoy.sh` | `envoy/` | Stop + disable systemd unit | Cleanup |
| `envoy/envoy-template-1.yaml` | `envoy/` | Envoy static cluster config (master backends) | Template |
| `envoy/envoy-template-2.yaml` | `envoy/` | Envoy listener config (admin, metrics) | Template |

---

## Tests

| Script | Intent | How it works |
|---|---|---|
| `tests/e2e-single-node.sh [lb_type]` | Validate full pipeline on one machine (fastest regression test) | Writes single-node `setup.conf`, sources each install script step-by-step via `bash -c ". script.sh"`, deploys LB → kubeadm init → Calico → smoke test. Cluster left running for inspection. |
| `tests/e2e-multi-node.sh [iterations]` | Validate cross-node pod networking on real multi-node cluster | Builds cluster via `echo 'y' | bash launch-cluster.sh`, creates nginx pods on both nodes with `nodeSelector`, tests HTTP both ways, tears down via `cleanup-all.sh`. Repeats for given iteration count. |
| `tests/test.sh [count]` | Stress-test — catch flaky failures across many install/teardown cycles | Picks random LB type each iteration, runs full install, dumps `kubectl get nodes` to `test-result.txt`, sleeps 30s, repeats. Default 20 iterations. |

Run any test from the project root:

```bash
# Single-node (envoy)
bash tests/e2e-single-node.sh

# Single-node (haproxy)
bash tests/e2e-single-node.sh haproxy

# Multi-node (1 iteration)
bash tests/e2e-multi-node.sh 1

# Stress test (10 iterations)
bash tests/test.sh 10
```

---

## File locations

```
k8s-easy-install/
├── cluster.sh                 # ← Entrypoint (run this)
├── launch-cluster.sh          # Orchestrator
├── setup.conf                 # Configuration (generated by menu, editable manually)
├── utils.sh                   # Shared helpers
├── kube-remove.sh
├── install-kubeadm.sh
├── kubeadm-init.sh            # Template
├── prepare-cluster-join.sh
├── install-cni-pluggin.sh     # Calico (note the typo in the filename)
├── init-self.sh
├── test-commands.sh           # Post-install smoke test
├── cleanup-all.sh             # Nuclear teardown
├── clean-trash.sh
├── copy-kube-config.sh
├── copy-init-log.sh
├── console.sh
├── confirm-action.sh
├── install-docker.sh          # Legacy no-op
├── AGENTS.md                  # Agent/assistant instructions
├── CHANGES.md                 # Revival change log
├── haproxy/
│   └── install-haproxy.sh, configure-haproxy.sh, start-haproxy.sh, stop-haproxy.sh
├── nginx/
│   └── install-nginx.sh, configure-nginx.sh, start-nginx.sh, stop-nginx.sh
├── envoy/
│   ├── install-envoy.sh, configure-envoy.sh, start-envoy.sh, stop-envoy.sh
│   └── envoy-template-1.yaml, envoy-template-2.yaml
├── tests/
│   ├── e2e-single-node.sh
│   ├── e2e-multi-node.sh
│   └── test.sh
└── test-result.txt            # Created by tests/test.sh
```

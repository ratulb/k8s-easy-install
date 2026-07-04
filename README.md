# k8s-easy-install

Spin up a Kubernetes cluster (single- or multi-master) from one machine — **no Ansible, no logging into each node** individually. Fronted by a choice of load balancers (haproxy, nginx, or envoy).

```
Controller ──SSH──► Loadbalancer (haproxy/nginx/envoy)
               ├──► Master 1 (kubeadm init)
               ├──► Master 2..N (join)
               └──► Workers (join via token)
```

## Prerequisites

- **root / sudo** access on the controller machine.
- **SSH public key** of the controller machine in `~/.ssh/authorized_keys` of every remote cluster node.
- Verified on Debian Buster and Ubuntu 16.04/18.04/20.04.

## Quick start

```bash
git clone https://github.com/ratulb/k8s-easy-install.git
cd k8s-easy-install
sudo ./cluster.sh
```

Follow the interactive menu:

<details>
<summary><b>Single-node cluster (all on one machine)</b></summary>

1. **Loadbalancer** — enter `localhost:6643` (port must differ from 6443).
2. Choose a load balancer type (haproxy/nginx/envoy).
3. **Master nodes** — enter the local machine's IP/hostname, then a blank line.
4. **Worker nodes** — skip (blank line) — all workloads run on the single node.
5. **Launch** — press `y` (not Enter) to confirm.

</details>

<details>
<summary><b>Multi-node cluster (separate machines)</b></summary>

1. **Loadbalancer** — enter the LB address and a port > 1000 (e.g. `10.0.0.10:6443`).
2. Choose a load balancer type.
3. **Master nodes** — enter hostnames or IPs, one per line, blank line to finish.
4. **Worker nodes** — same pattern.
5. **Launch** — press `y` to confirm.

</details>

---

## What happens when you launch

`launch-cluster.sh` orchestrates the entire installation in this order:

```
  1. Validate SSH connectivity to every node
  2. Install & configure chosen LB (haproxy/nginx/envoy)
  3. For every master:
       kube-remove.sh → install-kubeadm.sh
  4. First master only:
       kubeadm init (from template) → extract join commands → Weave CNI
  5. Remaining masters:
       master-join-cluster.cmd
  6. Workers:
       worker-join-cluster.cmd
  7. init-self.sh       — kubectl + kubeconfig on controller
  8. test-commands.sh   — demo nginx pod deployment
  9. clean-trash.sh     — remove temp files (unless $debug is set)
```

<details>
<summary><b>Template-based kubeadm-init</b></summary>

`kubeadm-init.sh` is a template containing placeholders:
- `#masters#` — replaced with space-separated master hostnames
- `#lb_port#` — the chosen LB port
- `#loadbalancer#` — the LB hostname/IP
- `#pod_network_cidr#` — optional pod CIDR

`launch-cluster.sh` copies it to `kubeadm-init.sh.tmp` and runs `sed` substitutions before sourcing it.

The join commands for additional masters and workers are extracted from the first master's `kubeadm-init.log` by `prepare-cluster-join.sh`.

</details>

---

## Reference

### `setup.conf` keys

| Key | Example | Description |
|---|---|---|
| `masters` | `m-1 m-2` | Space-separated master hostnames/IPs |
| `workers` | `w-1` | Space-separated worker hostnames/IPs (empty for single-node) |
| `loadbalancer` | `10.148.15.202` | LB hostname or IP |
| `lb_type` | `nginx` | One of: `haproxy`, `nginx`, `envoy` |
| `lb_port` | `6443` | LB listen port |
| `pod_network_cidr` | `10.244.0.0/16` | Optional pod CIDR for kubeadm |
| `sleep_time` | `3` | Default seconds between steps |
| `cri_containerd_cni_ver` | `1.3.4` | Containerd CNI version (informational) |

### File manifest

| File | Role | Runs on |
|---|---|---|
| `cluster.sh` | Interactive menu (entrypoint) | Controller |
| `launch-cluster.sh` | Orchestrator | Controller |
| `kube-remove.sh` | Nuke existing k8s installation | Each node |
| `install-kubeadm.sh` | Install kubeadm/kubelet/kubectl via apt | Each node |
| `install-docker.sh` | Docker CE (commented out in launch) | Each node |
| `kubeadm-init.sh` | Template for kubeadm init | First master |
| `prepare-cluster-join.sh` | Extract join commands from kubeadm-init.log | Controller |
| `install-cni-pluggin.sh` | Install Weave CNI | First master |
| `init-self.sh` | Setup kubectl + kubeconfig on controller | Controller |
| `test-commands.sh` | Post-install validation + demo nginx pod | Controller |
| `clean-trash.sh` | Remove generated temp files | Controller |
| `copy-kube-config.sh` | Sync kubeconfig between machines | Controller |
| `copy-init-log.sh` | Fetch kubeadm-init.log from remote master | Controller |
| `console.sh` | Interactive bash shell within menu | Controller |
| `confirm-action.sh` | Generic y/n prompt helper | Controller |
| `haproxy/` | HAProxy install/configure/start/stop scripts | LB node |
| `nginx/` | Nginx install/configure/start/stop scripts | LB node |
| `envoy/` | Envoy install/configure/start/stop scripts | LB node |
| `utils.sh` | Shared helpers (SSH, validation, config reading) | Everywhere |
| `tests/test.sh` | Loop-based integration test | Controller |

### Remote execution helpers (from `utils.sh`)

```bash
remote_script <host> <local-file>   # Run local script on remote host via SSH stdin
remote_cmd    <host> <args...>      # Run a command on remote host
remote_copy   <src> <dst>          # SCP with StrictHostKeyChecking=no
```

### Load balancer comparison

| LB | Config style | Runtime |
|---|---|---|
| haproxy | `/etc/haproxy/haproxy.cfg` — TCP mode `server` lines | systemd |
| nginx | `/etc/nginx/nginx.conf` — `stream` block with `$masters` | systemd |
| envoy | YAML templates → rendered config, run as systemd service | systemd |

### Runbook / menu index

| Menu option | What it does |
|---|---|
| **Loadbalancer** | Set LB address:port + type |
| **Master nodes** | Enter master hostnames/IPs (blank line = done) |
| **Worker nodes** | Same as masters |
| **Launch** | Validate config → run full install |
| **Reset configuration** | Clear all temporary inputs + wipe `setup.conf` fields |
| **Console** | Drop into interactive bash (`exit` to return) |
| **Kubelet status** | `systemctl status kubelet` on each master |
| **System pod status** | `kubectl -n kube-system get pod` |
| **Load balancer status** | Check LB service status |
| **Refresh view** | Re-exec the menu script |

---

## Testing

```bash
bash tests/test.sh [iteration_count]
```

Defaults to 20 iterations. Each iteration picks a random LB type, runs the full install, and writes results to `tests/test-result.txt`. The cluster is torn down between runs.

---

## Limitations

- **CNI plugin** — Only Weave is supported (hardcoded in `install-cni-pluggin.sh`). There is no option for flannel, Calico, or Cilium. To swap, replace the contents of `install-cni-pluggin.sh` with a different `kubectl apply -f <cni-manifest>`.
- **Docker** — The Docker install script (`install-docker.sh`) exists but is **commented out** in `launch-cluster.sh`. The project relies on containerd (bundled with kubeadm).
- **Controller not in cluster** — The controller machine itself is not joined as a node. `kubectl` is fetched as a standalone binary and configured via kubeconfig copied from the first master.

---

## Troubleshooting

<details>
<summary><b>SSH permission denied</b></summary>

```
$lb_address is not accessible. Has this machine's ssh key been added to $lb_address?
```

Ensure the controller's public key (`~/.ssh/id_rsa.pub` or equivalent) is appended to `~/.ssh/authorized_keys` on every remote node. Test with:

```bash
ssh -o StrictHostKeyChecking=no <user>@<remote-ip> ls
```

</details>

<details>
<summary><b>LB port conflicts with kube-apiserver</b></summary>

If the load balancer is on the same machine as a master and you use port 6443 for both, the install will fail because the port is already bound. Choose an LB port > 1000 that does not collide with any service port (e.g., 6643 for single-node, 7443 for multi-node).

The validation in `utils.sh:validate_multi-master-configuration` checks for this:

```
Loadbalancer address collides with ip $_ip yet loadbalancer port is 6443
```

</details>

<details>
<summary><b>Pods stuck in ContainerCreating / Pending</b></summary>

1. **CNI not installed** — Verify Weave pods are running:
   ```bash
   kubectl -n kube-system get pods | grep weave
   ```
2. **Node not ready** — Check node status:
   ```bash
   kubectl get nodes
   ```
3. **Taints** — The test script (`test-commands.sh`) removes the master taint for demo workloads. If you skip test-commands, you may need to taint manually:
   ```bash
   kubectl taint nodes --all node-role.kubernetes.io/master-
   ```

</details>

<details>
<summary><b>kubelet fails to start after install</b></summary>

On each node, `install-kubeadm.sh` configures sysctl and restarts kubelet. Check:

```bash
sudo journalctl -u kubelet --no-pager -n 50
```

Common causes:
- Swap is on (kubelet requires swap off)
- Wrong cgroup driver (containerd defaults to `systemd`, kubelet must match)
- Missing container runtime (verify containerd is running: `sudo systemctl status containerd`)

</details>

<details>
<summary><b>Node shows NotReady after join</b></summary>

Allow time for the CNI plugin to deploy (~30 seconds). If it persists:
- Check the CNI pod logs: `kubectl -n kube-system logs -l name=weave-net`
- Verify pod CIDR doesn't overlap with the host network
- If the first master's `--pod-network-cidr` was set, all nodes must use the same CIDR

</details>

<details>
<summary><b>Debug mode & preserving temp files</b></summary>

Run with `$debug` set to prevent cleanup and get verbose output:

```bash
debug=yes sudo ./cluster.sh
```

This preserves:
- `kubeadm-init.sh.tmp` — the rendered init template
- `kubeadm-init.log` — raw init output (contains join tokens)
- `*-join-cluster.cmd` — generated join commands
- `status-report` — `kubectl get nodes` / `kubectl get pods` output

</details>

<details>
<summary><b>Re-running after a failed attempt</b></summary>

**It is safe to re-run.** The flow always executes `kube-remove.sh` on each node before installing, which:
- Runs `kubeadm reset --force`
- Removes `/etc/kubernetes/`, `~/.kube/`, `/var/lib/kubelet/`, `/var/lib/etcd`
- Purges kubeadm/kubelet/kubectl packages
- Flushes iptables rules and kills orphan apiserver/etcd processes

Just re-launch from the menu and re-enter your configuration.

</details>

<details>
<summary><b>Controller says "Cluster may not have been setup yet"</b></summary>

The `system-pod-status.sh` script checks if `kubectl` is installed on the controller. If `init-self.sh` did not complete successfully (e.g., due to a network issue downloading the kubectl binary), re-run the launch flow. You can also manually install kubectl:

```bash
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl
```

Then fetch the kubeconfig from the first master:
```bash
scp <user>@<first-master>:~/.kube/config ~/.kube/config
```

</details>

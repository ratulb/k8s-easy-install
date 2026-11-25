# k8s-easy-install — AGENTS.md

## Entrypoint & invocation
- `sudo ./cluster.sh` — interactive menu-driven installer. Must run as root.
- No build system, test framework, or package manager. Pure bash scripts sourced via `. script.sh`.
- `utils.sh` auto-calls `read_setup` on source (line 23), so sourcing it immediately reads `setup.conf` into env vars.

## Configuration
- `setup.conf` — key-value file. Edit directly and re-run `cluster.sh` to pick up changes.
- Menu writes selections to `/tmp/*.txt` (lb_addr_and_port, selected_lb_type, master-ips-cluster-setup, worker-ips-cluster-setup), then `configure_multi_master_setup()` syncs them into `setup.conf`.

## Architecture
- **Controller machine** runs `cluster.sh`; SSH public key must be in `~/.ssh/authorized_keys` of every remote node. Passwordless sudo required on all remote nodes.
- **Single-node**: LB on localhost with port != 6443 (conflicts with kube-apiserver). Sequence: LB → Master → Launch (skip workers via blank line).
- **Multi-node**: LB installs first, then masters (first master runs `kubeadm init`), then workers join.
- Controller can be the first master (`masters=localhost`) or a separate machine: `init-self.sh` downloads `kubectl` binary and copies kubeconfig from first master.
- Three LB types: haproxy (apt), nginx (nginx.org repo), envoy (apt.envoyproxy.io). Each has `install.sh`, `configure.sh`, `start.sh`, `stop.sh` in its own subdirectory.

## Remote execution (from `utils.sh`)
- `remote_script <host> <file>` — runs a local script on remote host via SSH stdin.
- `remote_cmd <host> <args>` — runs command on remote host.
- `remote_copy <src> <dst>` — SCP with `StrictHostKeyChecking=no`.

## Key files
| File | Role |
|------|------|
| `launch-cluster.sh` | Orchestrator: validates SSH → installs LB → for each master: kube-remove + install-kubeadm → first master: kubeadm-init + prepare-cluster-join + install-cni-pluggin → remaining masters join → workers join → init-self → test-commands → clean-trash |
| `kube-remove.sh` | Nuclear cleanup: kubeadm reset, purge packages, remove apt repo/keyring/pin, reset containerd, flush iptables, kill orphan processes. **Always runs before install** (safe to re-run). |
| `cleanup-all.sh` | Full teardown: stops LB + removes its repos/keyrings, sources kube-remove.sh on every node + clean-trash.sh |
| `kubeadm-init.sh` | Template with `#masters#`, `#lb_port#`, `#loadbalancer#`, `#pod_network_cidr#` — copied to `.tmp` and `sed`-replaced before sourcing |
| `prepare-cluster-join.sh` | Extracts join commands from `kubeadm-init.log`, handling multi-line `\` continuations. Writes `worker-join-cluster.cmd` and `master-join-cluster.cmd`. |
| `install-cni-pluggin.sh` | Downloads Calico v3.32.1 manifest, patches IPIP→Never / VXLAN→Always, then `kubectl apply -f`. (Filename has intentional typo: "pluggin".) |
| `test-commands.sh` | Waits for nodes Ready, removes control-plane taint, deploys nginx from `https://raw.githubusercontent.com/ratulb/k8s-remote-install/main/nginx-deployment.yaml` |
| `init-self.sh` | Downloads kubectl binary if not on a cluster node, copies kubeconfig from first master |
| `install-docker.sh` | **No-op** — Docker is removed if present; containerd is used directly |
| `console.sh` | Interactive bash within the menu (`exit` to return) |
| `$debug` env var | Suppresses temp file cleanup and enables `debug()` print calls: `debug=yes sudo ./cluster.sh` |

## Template rendering
`launch-cluster.sh` copies `kubeadm-init.sh` → `kubeadm-init.sh.tmp`, then runs four `sed -i` substitutions before the `.tmp` file is sourced (not executed) on the first master. Generated join commands and temp files are in `.gitignore`.

## Tests
Run from project root. All require passwordless sudo and (for multi-node) SSH key access to remote nodes.

| Command | Purpose |
|---------|---------|
| `bash tests/e2e-single-node.sh [lb_type]` | Fast regression: writes single-node `setup.conf`, sources each step in order. LB types: envoy (default), nginx, haproxy. **Leaves cluster running.** |
| `bash tests/e2e-multi-node.sh [iterations]` | Validates cross-node pod networking (HTTP both ways via Calico VXLAN). Reads existing `setup.conf`. Builds `echo y \| launch-cluster.sh` → test → `cleanup-all.sh`. Default 1 iteration. |
| `bash tests/e2e-nginx-8080.sh [single\|all-masters\|all]` | Regression for nginx LB on port 8080: `single` uses localhost as LB+master; `all-masters` promotes every node from `setup.conf` to control-plane and puts the LB on a remote master (exercises remote install). Verifies `listen 8080`, active service, `https://<lb>:8080/healthz`, and all nodes Ready. Restores original `setup.conf` on exit. |
| `bash tests/test.sh [count]` | Stress test (default 20 iterations): random LB type each iteration, dumps `kubectl get nodes` to `tests/test-result.txt`. **Does NOT run cleanup between iterations** (known limitation). |

## Gotchas
- `install-kubeadm.sh` installs containerd if missing, removes Docker if present, configures `SystemdCgroup = true`, and `apt-mark hold`s kubelet/kubeadm/kubectl.
- `kube-remove.sh` resets containerd (stop → wipe `/var/lib/containerd` → regenerate config → restart) for a clean state.
- `test-commands.sh` applies a remote nginx manifest (requires internet access to GitHub).
- Cross-node pod networking requires VXLAN (UDP 4789) — IPIP is disabled because it's blocked in most clouds.
- All changes from the 2026 revival are tracked in [`CHANGES.md`](./CHANGES.md).

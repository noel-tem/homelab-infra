# homelab-infra

Infrastructure for my home Proxmox server (`live-laugh-homelab`, 192.168.0.50).

- **OpenTofu** creates the guests (`stacks/homelab/`) and owns the Tailscale key, route approval and split DNS (`stacks/tailnet/`).
- **Ansible** (`ansible/`) configures everything inside them, plus the Proxmox host itself.

## Services

| Guest | ID | Direct address | Name | Notes |
|---|---|---|---|---|
| Pi-hole | 100 | http://192.168.0.10/admin | http://pihole.home.arpa | LAN DNS (port 53); holds the `*.home.arpa` records |
| Home Assistant OS | 102 | http://192.168.0.83:8123 | http://homeassistant.home.arpa | VM from community-scripts, imported into Tofu |
| Mosquitto | 104 | `mqtt://192.168.0.20:1883` | — | MQTT broker, no Ansible config yet |
| Caddy | 105 | http://192.168.0.21 | — | Reverse proxy for every `*.home.arpa` name |
| Gitea | 106 | http://192.168.0.22:3000 | http://gitea.home.arpa | First visit runs the web installer |
| Jellyfin | 107 | http://192.168.0.23:8096 | http://jellyfin.home.arpa | iGPU passthrough, 100G media volume shared over SMB at `\\192.168.0.23\media` |
| Uptime Kuma | 108 | http://192.168.0.24:3001 | http://uptime.home.arpa | Uptime checks and alerts; first visit creates the admin account |
| Metrics | 109 | http://192.168.0.25:3000 | http://grafana.home.arpa | Grafana (first login `admin`/`admin`) + InfluxDB on :8086, fed by Proxmox |

The direct addresses and the `.home.arpa` names work anywhere the LAN is reachable, including over Tailscale.

Everything except Home Assistant is an unprivileged Debian 13 LXC built from [`modules/lxc`](modules/lxc/).

### How names resolve

Pi-hole points every `<name>.home.arpa` at Caddy, and Caddy proxies it to the right `ip:port`. Both are driven by `proxied_services` in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml), so adding a service there is all it takes to give it a name.

Note: the Pi-hole role overwrites the whole local DNS list, so records added in the Pi-hole web UI get replaced.

### Remote access

The Proxmox host runs Tailscale as a subnet router advertising `192.168.0.0/24` to the tailnet. Tofu mints the auth key and approves the route; Ansible installs Tailscale and joins the host. Nothing inside the containers runs Tailscale.

The tailnet policy (ACLs, tag owners, SSH rules) lives in [`stacks/tailnet/policy.hujson.tftpl`](stacks/tailnet/policy.hujson.tftpl). Edit it there, not in the admin console: the next `tofu apply` overwrites console changes.

Tofu also sets a split-DNS rule on the tailnet that sends `home.arpa` lookups to Pi-hole over that route, so the names work remotely too.

## Layout

```
modules/lxc/        reusable LXC container module
stacks/homelab/     the actual guests
stacks/tailnet/     Tailscale key, route approval + split DNS (kept apart so guest changes can't touch remote access)
ansible/
  site.yml          runs everything
  playbooks/        one per host/service
  roles/            caddy, gitea, jellyfin, media_share, gpu_passthrough, pihole_dns, subnet_router,
                    uptime_kuma, influxdb, grafana, metrics_server
  group_vars/       shared vars (guest IDs/IPs, domain, proxied services)
```

Guest IDs and IPs live only in `guests` in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml). Tofu reads that same file, so changing an address there updates both.

## Prerequisites

- OpenTofu and Ansible (`ansible-core` + `paramiko`, e.g. via pipx)
- Optional: [pre-commit](https://pre-commit.com) (`pre-commit install`) to run `tofu fmt`, `tofu validate` and `ansible-lint` on commit
- An SSH key at `~/.ssh/id_ed25519` that can log in as root on the Proxmox host
- A Proxmox API token
- A Tailscale OAuth client with scopes `auth_keys` (tag `tag:homelab`), `devices:core:read`, `devices:routes`, `dns` and `policy_file`

Secrets live in a gitignored `.env` at the repo root (loaded by direnv via `.envrc`):

```sh
export PROXMOX_VE_ENDPOINT=https://192.168.0.50:8006/
export PROXMOX_VE_API_TOKEN=user@realm!token=secret
export TF_VAR_state_passphrase=...           # encrypts Tofu state and plans
export TAILSCALE_OAUTH_CLIENT_ID=...
export TAILSCALE_OAUTH_CLIENT_SECRET=...
export TF_VAR_r2_account_id=...             # Cloudflare account ID
export TF_VAR_r2_bucket=...                 # R2 bucket holding the state
export AWS_ACCESS_KEY_ID=...                # R2 API token (Object Read & Write on that bucket)
export AWS_SECRET_ACCESS_KEY=...
export INFLUXDB_TOKEN=...                   # e.g. openssl rand -hex 32; Grafana and Proxmox use it on every run
export INFLUXDB_PASSWORD=...                # InfluxDB admin; only read when InfluxDB is first set up
```

## Usage

### Create / change guests

```sh
cd stacks/homelab
tofu init
tofu plan
tofu apply
```

The Tailscale side is the same in `stacks/tailnet`; it only needs the Tailscale and R2 credentials.

On a fresh build the host isn't on the tailnet yet, so it takes two applies: `tofu apply` (mints the auth key), then `ansible-playbook playbooks/proxmox-host.yml` within the hour (joins the host), then `tofu apply` again (approves the route).

State lives in the R2 bucket at `homelab/terraform.tfstate` and `tailnet/terraform.tfstate`, each encrypted with `TF_VAR_state_passphrase` before upload. Keep the passphrase in a password manager too: without it the state can't be read.

### Configure them

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml

# dry run first
ansible-playbook site.yml --check --diff
ansible-playbook site.yml

# or just one service
ansible-playbook playbooks/jellyfin.yml
```

Ansible never SSHes into containers. It connects to the Proxmox host as root and uses `pct exec` (the `community.proxmox.proxmox_pct_remote` connection), so containers don't need sshd or keys. `site.yml` bootstraps Python in each container before anything else.

The first Jellyfin run creates the SMB account and needs a password in the environment:

```sh
MEDIA_SHARE_PASSWORD=... ansible-playbook playbooks/jellyfin.yml
```

After that, change it with `smbpasswd media` inside the container. The share is `\\192.168.0.23\media`.

### Monitoring

`playbooks/metrics.yml` installs InfluxDB and Grafana, then points Proxmox's metric server (Datacenter → Metric Server) at InfluxDB. Proxmox pushes host and guest stats into the `proxmox` bucket, which keeps 30 days. Grafana already has InfluxDB as its data source. For dashboards, import [Proxmox [Flux]](https://grafana.com/grafana/dashboards/15356) (ID `15356`) under Dashboards → New → Import.

Uptime Kuma's monitors and notifications are set up in its web UI. They aren't in this repo.

## Gotchas

- **Containers use Pi-hole for DNS** (`dns_servers = ["192.168.0.10"]`) because the host's `resolv.conf` points at Tailscale's resolver, which containers can't reach.
- **Rejoining Tailscale**: the auth key is single-use and expires an hour after creation. Mint a fresh one with `tofu -chdir=stacks/tailnet apply -replace=tailscale_tailnet_key.subnet_router`, then rerun Ansible.
- **GPU passthrough is done by Ansible, not Tofu**: device passthrough needs `root@pam`, and Tofu uses an API token. The module ignores `device_passthrough` changes for the same reason.
- **Changing the LXC template** won't rebuild existing containers; the module ignores template changes. Tofu downloads the template (`proxmox_download_file.debian_13` in `locals.tf`), so bump its URL and checksum to change it.
- **Tailscale OAuth scope errors** show up as 404s, not 403s.
- **Home Assistant**'s guest agent reports internal interfaces with changing MACs, so `mac_addresses` is ignored.


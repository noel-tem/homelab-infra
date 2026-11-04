# homelab-infra

Infrastructure for my home Proxmox cluster: `live-laugh-homelab` (192.168.0.50) and `live-laugh-tomcruise` (192.168.0.51), with a QDevice for quorum.

- **OpenTofu** creates the guests (`stacks/homelab/`) and owns the Tailscale key, route approval and split DNS (`stacks/tailnet/`).
- **Ansible** (`ansible/`) configures everything inside them, plus the Proxmox nodes themselves.

## Services

| Guest | ID | Direct address | Name | Notes |
|---|---|---|---|---|
| Pi-hole | 100 | http://192.168.0.10/admin | http://pihole.home.arpa | LAN DNS (port 53); holds the `*.home.arpa` records |
| Pi-hole 2 | 101 | http://192.168.0.11/admin | http://pihole2.home.arpa | On `live-laugh-tomcruise`; failover for Pi-hole, configured identically by Ansible |
| Home Assistant OS | 102 | http://192.168.0.83:8123 | http://homeassistant.home.arpa | VM from community-scripts, imported into Tofu |
| Mosquitto | 104 | `mqtt://192.168.0.20:1883` | — | MQTT broker, no Ansible config yet |
| Caddy | 105 | http://192.168.0.21 | — | Reverse proxy for every `*.home.arpa` name; normally holds the VIP `192.168.0.28` |
| Caddy 2 | 111 | http://192.168.0.27 | — | On `live-laugh-tomcruise`; failover for Caddy, takes over the VIP when it's down |
| Gitea | 106 | http://192.168.0.22:3000 | http://gitea.home.arpa | On `live-laugh-tomcruise`; first visit runs the web installer |
| Jellyfin | 107 | http://192.168.0.23:8096 | http://jellyfin.home.arpa | On `live-laugh-tomcruise`; iGPU passthrough, media volume filling its 2 TB HDD, shared over SMB at `\\192.168.0.23\media` |
| Uptime Kuma | 108 | http://192.168.0.24:3001 | http://uptime.home.arpa | Uptime checks and alerts; first visit creates the admin account |
| Metrics | 109 | http://192.168.0.25:3000 | http://grafana.home.arpa | Grafana (first login `admin`/`admin`) + InfluxDB on :8086, fed by Proxmox |
| Proxmox Backup Server | 110 | https://192.168.0.26:8007 | http://pbs.home.arpa | On `live-laugh-tomcruise`; datastore filling its 1 TB SSD. Log in as `admin@pbs` |
| Runner | 112 | 192.168.0.29 | — | Gitea Actions runner for Claude and lint jobs; no infra credentials (see [CI](#ci)) |
| Deployer | 113 | 192.168.0.30 | — | Applies every new commit on `main` (see [CI](#ci)) |

The direct addresses and the `.home.arpa` names work anywhere the LAN is reachable, including over Tailscale.

Everything except Home Assistant is an unprivileged Debian 13 LXC built from [`modules/lxc`](modules/lxc/).

### How names resolve

Pi-hole points every `<name>.home.arpa` at Caddy's VIP, and Caddy proxies it to the right `ip:port`. Both are driven by `proxied_services` in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml), so adding a service there is all it takes to give it a name.

Note: the Pi-hole role overwrites the whole local DNS list, so records added in the Pi-hole web UI get replaced.

### DNS failover

There are two Pi-holes, one per node, and Ansible keeps them identical: upstreams and blocklists come from [`ansible/roles/pihole/defaults/main.yml`](ansible/roles/pihole/defaults/main.yml), local records from `proxied_services`. Change blocklists there, not in either web UI, since the next run replaces them. Allowlists and anything else set in the UI only exist on the Pi-hole you set them on.

Every container and the tailnet's split DNS list both Pi-holes. LAN clients only get both if the router's DHCP hands out `192.168.0.10` and `192.168.0.11` as DNS servers; that's set on the router, not here.

Both Pi-holes point the `*.home.arpa` names at Caddy, so with either node down, DNS and the names keep working (see below).

### Proxy failover

There are two Caddys too, one per node, configured identically by Ansible. They share a virtual IP, `caddy_vip` (`192.168.0.28`) in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml), which is what the Pi-hole records point at. keepalived ([`ansible/roles/keepalived`](ansible/roles/keepalived/)) gives the VIP to `caddy` and moves it to `caddy2` within a few seconds if that container, its node or the Caddy service goes down. It moves back once `caddy` recovers.

The proxied services themselves aren't duplicated: with `live-laugh-tomcruise` down, `gitea.home.arpa` still resolves and reaches a Caddy, but Gitea isn't there to answer.

### Remote access

Every Proxmox node runs Tailscale as a subnet router advertising `192.168.0.0/24`, so the tailnet fails over if one node is down. Tofu mints an auth key per node and approves each route; Ansible installs Tailscale and joins the nodes. Nothing inside the containers runs Tailscale.

The tailnet policy (ACLs, tag owners, SSH rules) lives in [`stacks/tailnet/policy.hujson.tftpl`](stacks/tailnet/policy.hujson.tftpl). Edit it there, not in the admin console: the next `tofu apply` overwrites console changes.

Tofu also sets a split-DNS rule on the tailnet that sends `home.arpa` lookups to Pi-hole over that route, so the names work remotely too.

## Layout

```
modules/lxc/        reusable LXC container module
stacks/homelab/     the actual guests
stacks/tailnet/     Tailscale key, route approval + split DNS (kept apart so guest changes can't touch remote access)
ansible/
  site.yml          runs everything
  connection_plugins/  pct: the faster container connection
  playbooks/        one per host/service
  roles/            caddy, keepalived, gitea, jellyfin, media_share, gpu_passthrough, pihole, pihole_dns, subnet_router,
                    uptime_kuma, influxdb, grafana, metrics_server, auto_updates, disk_storage, pbs, pbs_storage,
                    opentofu, ansible_tools, gitea_runner, claude_code, deployer
  group_vars/       shared vars (guest IDs/IPs, domain, proxied services)
.gitea/workflows/   CI: check (lint + validate on PRs) and claude (@claude on issues)
```

Guest IDs, IPs and nodes live only in `guests` in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml), and the cluster nodes in `nodes` next to it. Tofu reads that same file, so changing an address there updates both.

## Prerequisites

- OpenTofu and Ansible (`ansible-core` + `paramiko`, e.g. via pipx)
- Optional: [pre-commit](https://pre-commit.com) (`pre-commit install`) to run `tofu fmt`, `tofu validate` and `ansible-lint` on commit
- An SSH key at `~/.ssh/id_ed25519` that can log in as root on every Proxmox node
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
export PBS_ADMIN_PASSWORD=...               # admin@pbs on PBS; only read when that user is created
export PIHOLE_PASSWORD=...                  # Pi-hole web UI; only read when Ansible installs a new Pi-hole
export DEPLOYER_GITEA_TOKEN=...             # the deployer bot's Gitea token (see CI)
```

`playbooks/ci.yml` copies all of these except the Tailscale ones to the deployer. It stops if any is unset, except the three that are only read on first setup (`INFLUXDB_PASSWORD`, `PBS_ADMIN_PASSWORD`, `PIHOLE_PASSWORD`), which it copies only if set.

## Usage

### Create / change guests

```sh
cd stacks/homelab
tofu init
tofu plan
tofu apply
```

The Tailscale side is the same in `stacks/tailnet`; it only needs the Tailscale and R2 credentials.

On a fresh build (or a new node) the node isn't on the tailnet yet, so it takes two applies: `tofu apply` (mints the auth key), then `ansible-playbook playbooks/proxmox-host.yml` within the hour (joins the node), then `tofu apply` again (approves the route).

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

Ansible never SSHes into containers. It connects as root to the node each container is on and runs commands inside with `lxc-attach`, so containers don't need sshd or keys. The connection is [`connection_plugins/pct.py`](ansible/connection_plugins/pct.py): `community.proxmox.proxmox_pct_remote` with pipelining, and `lxc-attach` instead of `pct exec` (the same thing behind a slow Perl wrapper). Without those, every task took about 6 seconds. It overrides a private method of that collection, so check it still works after upgrading `community.proxmox`. `site.yml` bootstraps Python in each container before anything else.

The first Jellyfin run creates the SMB account and needs a password in the environment:

```sh
MEDIA_SHARE_PASSWORD=... ansible-playbook playbooks/jellyfin.yml
```

After that, change it with `smbpasswd media` inside the container. The share is `\\192.168.0.23\media`.

### Monitoring

`playbooks/metrics.yml` installs InfluxDB and Grafana, then points Proxmox's metric server (Datacenter → Metric Server) at InfluxDB. Proxmox pushes host and guest stats into the `proxmox` bucket, which keeps 30 days. Grafana already has InfluxDB as its data source. For dashboards, import [Proxmox [Flux]](https://grafana.com/grafana/dashboards/15356) (ID `15356`) under Dashboards → New → Import.

Uptime Kuma's monitors and notifications are set up in its web UI. They aren't in this repo.

### Backups

`playbooks/pbs.yml` installs Proxmox Backup Server and connects the cluster to it as storage `pbs`. A nightly job (`nightly`, 02:00) backs up every guest in snapshot mode, keeping 7 daily, 4 weekly and 3 monthly backups. PBS verifies each new backup and runs garbage collection on Saturdays. Volumes marked `backup = false`, like Jellyfin's media and PBS's own datastore, are skipped.

The datastore takes up all of the M75s's 1 TB SSD, and Jellyfin's media volume all of its 2 TB HDD. `disk_storage` (in `playbooks/proxmox-host.yml`) turns them into LVM storage `ssd-lvm` and `hdd-lvm`. That role wipes each disk the first time it runs, and never again once its volume group (`ssd`, `hdd`) exists. On a fresh build, run `proxmox-host.yml` before `tofu apply`, since the PBS and Jellyfin containers' volumes need that storage.

The backups are on the same premises as the guests, so they don't cover losing both machines.

### CI

Merging to `main` deploys it, and `@claude` on an issue gets a PR. It's split across two containers so the infra credentials never meet code you haven't approved:

- **runner** is the only Gitea Actions runner (label `claude`). It runs [`check`](.gitea/workflows/check.yml) (fmt, validate, ansible-lint) on every PR and [`claude`](.gitea/workflows/claude.yml) when you write `@claude` in a new issue or an issue comment. Claude edits a `claude/issue-<n>` branch, and the workflow pushes it, opens a PR and replies on the issue. The runner only holds Claude's two secrets, no infra credentials.
- **deployer** isn't a runner, so no workflow can reach it. Every 2 minutes it fetches `main`, and for each new commit it runs `tofu apply` on `stacks/homelab`, then `ansible-playbook site.yml`. A plan that deletes or replaces anything isn't applied: the deploy fails and you apply it by hand. The result shows as a `deploy` status on the commit. Logs: `journalctl -u deployer` on the deployer. Each commit is tried once; to try it again, run `touch /var/lib/deployer/retry && systemctl start deployer`. On its first run, and whenever `last-attempted` is missing, it marks whatever's on `main` as deployed without applying anything.
- **`stacks/tailnet` is never auto-applied.** Apply it by hand as before, so a merge can't cut remote access. The deployer doesn't have the Tailscale credentials at all.
- Before Claude's changes are committed, the workflow checks them for Claude's tokens and anything shaped like an Anthropic key. If it finds one it stops without pushing, because the branch would be on public GitHub seconds later.

Runner labels only route jobs. They don't restrict them, so any branch could send a job to any runner. That's why the infra credentials sit on a host that only ever runs `main`, and `main` only gets code through branch protection.

One-time setup in Gitea, before `playbooks/ci.yml`:

1. Create two bot users, `claude` and `deployer`, and add both to `homelab-infra` as **Write** collaborators.
2. Tokens: `deployer` gets `write:repository` (for commit statuses), which goes in `.env` as `DEPLOYER_GITEA_TOKEN`. `claude` gets `write:repository` + `write:issue`, which goes in the repo's Actions secrets as `CLAUDE_GITEA_TOKEN`.
3. Run `claude setup-token` and add the result to the repo's Actions secrets as `CLAUDE_CODE_OAUTH_TOKEN`.
4. Branch protection on `main`, which is the approval gate:
   - **Disable push** for everyone, you included, so every change reaches `main` through a PR.
   - **Merge whitelist: `noeltem` only.** Your merge is the approval. Leave required approvals at 0, since Gitea doesn't let you approve your own PRs, so a 1 would block them.
   - **Apply to administrators**, so the owner account can't bypass it either.
   - Optionally require the `Check` status, once it has run once.

   Then check it works: a push to `main` with the claude bot's token should be rejected. For an emergency fix that can't wait for a PR, apply it locally with `tofu`/`ansible-playbook`, then get it onto `main` through a PR. Otherwise the next deploy reverts it.

Then `tofu apply` in `stacks/homelab` (creates both containers) and `ansible-playbook playbooks/ci.yml`. That run registers the runner with Gitea and authorizes the deployer's SSH key on the nodes.

Both of Claude's secrets are readable by any workflow on any branch, which is fine since they're only Claude's. Anything committed still goes to the public GitHub mirror.

## Gotchas

- **Containers use the Pi-holes for DNS** (`dns_servers = local.pihole_ips`) because the host's `resolv.conf` points at Tailscale's resolver, which containers can't reach.
- **Rejoining Tailscale**: the auth key is single-use and expires an hour after creation. Mint a fresh one with `tofu -chdir=stacks/tailnet apply -replace='tailscale_tailnet_key.subnet_router["<node>"]'`, then rerun Ansible.
- **GPU passthrough is done by Ansible, not Tofu**: device passthrough needs `root@pam`, and Tofu uses an API token. The module ignores `device_passthrough` changes for the same reason.
- **Changing the LXC template** won't rebuild existing containers; the module ignores template changes. Tofu downloads the template to every node (`proxmox_download_file.debian_13` in `locals.tf`), so bump its URL and checksum to change it.
- **Tailscale OAuth scope errors** show up as 404s, not 403s.
- **Home Assistant**'s guest agent reports internal interfaces with changing MACs, so `mac_addresses` is ignored.


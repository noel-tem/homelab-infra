# homelab-infra

Infrastructure for my home Proxmox cluster of three nodes: `live-laugh-homelab` (192.168.0.50), `live-laugh-tomcruise` (192.168.0.51) and `live-laugh-nicolekidman` (192.168.0.52). Any one of them can be down without the cluster losing quorum.

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
| Jellyfin | 107 | http://192.168.0.23:8096 | http://jellyfin.home.arpa | On `live-laugh-nicolekidman`; iGPU passthrough; the media on its mergerfs pool (shared with arr), also over SMB at `\\192.168.0.23\media` |
| Uptime Kuma | 108 | http://192.168.0.24:3001 | http://uptime.home.arpa | Uptime checks and alerts; first visit creates the admin account |
| Metrics | 109 | http://192.168.0.25:3000 | http://grafana.home.arpa | Grafana (first login `admin`/`admin`) + InfluxDB on :8086, fed by Proxmox |
| Proxmox Backup Server | 110 | https://192.168.0.26:8007 | http://pbs.home.arpa | On `live-laugh-tomcruise`; datastore filling its 1 TB SSD. Log in as `admin@pbs` |
| Proxmox Backup Server 2 | 115 | https://192.168.0.32:8007 | http://pbs2.home.arpa | On `live-laugh-nicolekidman`; a second copy of every backup, on its 1 TB HDD (see [Backups](#backups)) |
| Runner | 112 | 192.168.0.29 | — | Gitea Actions runner for Claude and lint jobs; no infra credentials (see [CI](#ci)) |
| Deployer | 113 | 192.168.0.30 | — | Applies every new commit on `main` (see [CI](#ci)) |
| Arr | 114 | 192.168.0.31 | http://sonarr.home.arpa, radarr, prowlarr, bazarr, qbit, seerr | On `live-laugh-nicolekidman`; Docker Compose stack, qBittorrent behind Surfshark (see [Media](#media)) |

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
  roles/            caddy, keepalived, gitea, jellyfin, media_share, media_mount, gpu_passthrough, tun_passthrough, arr,
                    pihole, pihole_dns, subnet_router,
                    uptime_kuma, influxdb, grafana, metrics_server, auto_updates, disk_storage, pbs, pbs_storage,
                    opentofu, ansible_tools, gitea_runner, claude_code, deployer
  group_vars/       shared vars (guest IDs/IPs, domain, proxied services)
.gitea/workflows/   CI: check (lint + validate on PRs) and claude (@claude on issues)
```

Guest IDs, IPs and nodes live only in `guests` in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml), and the cluster nodes in `nodes` next to it. Tofu reads that same file, so changing an address there updates both.

A guest's `node` there is where Tofu creates it. Moving a guest afterwards (by hand, or by HA) needs no change: Tofu ignores the node of an existing guest, and every playbook that configures containers starts with [`playbooks/locate-guests.yml`](ansible/playbooks/locate-guests.yml), which asks the cluster where each one is running and connects through that node.

To switch Jellyfin or arr off, set `running: false` on it there: Tofu stops it and keeps it from starting on boot, and Ansible skips it, since a stopped container can't be configured. The other guests still use the `<name>_running` local in their `.tf` file, which only Tofu reads.

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
export SURFSHARK_WIREGUARD_PRIVATE_KEY=...  # Surfshark WireGuard key (see Media); only read when arr is first set up
export SURFSHARK_WIREGUARD_ADDRESS=...      # the Address line of a Surfshark WireGuard config, e.g. 10.14.0.2/16
```

`playbooks/ci.yml` copies all of these except the Tailscale ones to the deployer. It stops if any is unset, except the ones that are only read on first setup (`INFLUXDB_PASSWORD`, `PBS_ADMIN_PASSWORD`, `PIHOLE_PASSWORD` and the two `SURFSHARK_` ones), which it copies only if set.

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

### Media

Jellyfin and the arr stack are separate containers on `media_node` (`live-laugh-nicolekidman`) that share one folder. Its three 2 TB HDDs are pooled into one 5.4 TB filesystem at `/mnt/pool` with [mergerfs](https://trapexit.github.io/mergerfs/), and `/mnt/pool/media` is bind-mounted into both at `/mnt/media` ([`roles/media_mount`](ansible/roles/media_mount/)). Downloads and the library are on the same filesystem, so Sonarr and Radarr import with hardlinks instead of copies:

```
/mnt/media/downloads/{tv,movies,anime}   qBittorrent saves here, one category each
/mnt/media/{shows,movies,anime}          Sonarr/Radarr hardlink here; Jellyfin's libraries
```

The media has no redundancy, on purpose. Each disk is plain ext4, and mergerfs spreads new files across them by free space (`category.create=pfrd`) and keeps a hardlink on the same disk as its file. Losing a disk loses only the files on it, which Sonarr and Radarr then show as missing.

Everything is owned by the `library` group (gid 2000, set in `group_vars/all.yml`), which exists in both containers with Jellyfin in it. The apps run as `arr` (uid 2000) with umask 002, so neither side locks the other out.

The arr container runs [Docker Compose](ansible/roles/arr/templates/compose.yaml.j2) in `/opt/arr`, with each app's config in `/var/lib/arr/<app>` (backed up by PBS). Inside the stack, apps reach each other by service name: in Sonarr and Radarr, add qBittorrent as host `gluetun`, port `8080`, and use `/data/...` paths (qBittorrent, Sonarr, Radarr and Bazarr all see the media at `/data`). Point Prowlarr at `http://sonarr:8989` and `http://radarr:7878`, and Seerr at Jellyfin on `http://192.168.0.23:8096`. For indexers behind Cloudflare, add FlareSolverr in Prowlarr under Settings → Indexers → Indexer Proxies (host `http://flaresolverr:8191`, with a tag such as `flaresolverr`), then give those indexers the same tag. qBittorrent prints a temporary web UI password on first start: `docker compose -f /opt/arr/compose.yaml logs qbittorrent`.

qBittorrent uses gluetun's network, so torrent traffic only leaves through Surfshark's WireGuard tunnel, and stops if the tunnel is down. Surfshark doesn't forward ports, so peers can't connect in. Downloads work, but seeding is weak. To get the key, in the Surfshark dashboard go to VPN → Manual setup → Router → WireGuard, generate a key pair, and download a config for any location. The private key goes in `.env` as `SURFSHARK_WIREGUARD_PRIVATE_KEY` and the config's `Address` as `SURFSHARK_WIREGUARD_ADDRESS`. The first `playbooks/arr.yml` run writes them to `/opt/arr/vpn.env`; after that, edit that file and rerun the playbook. The server country is `arr_vpn_countries` in [`roles/arr/defaults/main.yml`](ansible/roles/arr/defaults/main.yml).

Images use `latest` tags and aren't updated automatically. To update, run `docker compose pull && docker compose up -d` in `/opt/arr`.

The bind mounts and the arr container's `/dev/net/tun` are set by Ansible with `pct set`, because both need `root@pam` and Tofu uses an API token. The LXC module ignores `mount_point` changes for that reason.

#### Setting up the disks by hand

The disks and mergerfs on `live-laugh-nicolekidman` aren't managed by Ansible, so after reinstalling the node, redo this. Formatting erases the disks:

```sh
mkfs.ext4 -L disk0 /dev/disk/by-id/ata-ST2000DM001-1ER164_Z4Z0BAQY
mkfs.ext4 -L disk1 /dev/disk/by-id/ata-ST2000DL003-9VT166_5YD6NFH7
mkfs.ext4 -L disk2 /dev/disk/by-id/ata-ST2000DL003-9VT166_5YD6NFHC
mkdir -p /mnt/hdd/disk{0,1,2} /mnt/pool
apt install mergerfs
```

`/etc/fstab`:

```
LABEL=disk0 /mnt/hdd/disk0 ext4 defaults,noatime,nofail 0 2
LABEL=disk1 /mnt/hdd/disk1 ext4 defaults,noatime,nofail 0 2
LABEL=disk2 /mnt/hdd/disk2 ext4 defaults,noatime,nofail 0 2
/mnt/hdd/disk2/pool:/mnt/hdd/disk1/pool:/mnt/hdd/disk0/pool /mnt/pool fuse.mergerfs cache.files=off,category.create=pfrd,func.getattr=newest,dropcacheonclose=false,allow_other,minfreespace=50G,fsname=pool,x-systemd.after=/mnt/hdd/disk0,x-systemd.after=/mnt/hdd/disk1 0 0
```

Then `systemctl daemon-reload && mount -a`, and once the disks are mounted:

```sh
mkdir /mnt/hdd/disk{0,1,2}/pool
mkdir /mnt/pool/media && chown 100000:102000 /mnt/pool/media && chmod 2775 /mnt/pool/media
```

- Each branch is a `pool` folder on its disk, which only exists while that disk is mounted, so a missing disk is skipped instead of mergerfs writing to the SSD in its place.
- systemd reads the pool's first branch as a path, so the pool requires that disk to mount; the youngest disk (`disk2`) goes first, and the other two are only waited for (`x-systemd.after`). `nofail` lets the node boot with a disk missing.
- `100000:102000` is the containers' root and `library` group as the host sees them.
- The media folders (`media_dirs` in `group_vars/all.yml`) are made by Ansible on the node, not in the containers: on the pool, a container's root acts as its host user (100000), which can't change owners, so creating them from inside fails.

### Monitoring

`playbooks/metrics.yml` installs InfluxDB and Grafana, then points Proxmox's metric server (Datacenter → Metric Server) at InfluxDB. Proxmox pushes host and guest stats into the `proxmox` bucket, which keeps 30 days. Grafana already has InfluxDB as its data source. For dashboards, import [Proxmox [Flux]](https://grafana.com/grafana/dashboards/15356) (ID `15356`) under Dashboards → New → Import.

Uptime Kuma's monitors and notifications are set up in its web UI. They aren't in this repo.

### Backups

`playbooks/pbs.yml` installs Proxmox Backup Server and connects the cluster to it as storage `pbs`. A nightly job (`nightly`, 02:00) backs up every guest in snapshot mode, keeping 7 daily, 4 weekly and 3 monthly backups. PBS verifies each new backup and runs garbage collection on Saturdays. Volumes marked `backup = false`, like PBS's own datastore, are skipped, and so are bind mounts like the media.

The datastore takes up all of the M75s's 1 TB SSD. `disk_storage` (in `playbooks/proxmox-host.yml`) turns it into LVM storage `ssd-lvm`, wiping the disk the first time it runs and never again once the `ssd` volume group exists. On a fresh build, run `proxmox-host.yml` before `tofu apply`, since PBS's volume needs that storage.

`pbs2`, on `live-laugh-nicolekidman`, holds a second copy ([`roles/pbs_sync`](ansible/roles/pbs_sync/)):

- At 05:00 it pulls every new backup from `pbs`, logging in as `sync@pbs`, which can only read there.
- It keeps what it pulled even after `pbs` prunes or loses it, and prunes on its own at 07:00, on the same 7 daily, 4 weekly and 3 monthly terms.
- On Sundays it re-reads any copy it hasn't checked in 30 days, and runs garbage collection on Saturdays.
- The cluster has it as storage `pbs2`, read-only, for restores. Nothing backs up to it directly, and a node can't delete from it.

If `pbs`, its SSD or `live-laugh-tomcruise` is lost, restore from `pbs2` instead: pick the backup under storage `pbs2` in the web UI. Its datastore takes up the node's 1 TB HDD, as LVM storage `hdd-backup`, set up by hand:

```sh
vgcreate backup /dev/disk/by-id/ata-WDC_WD10EZEX-60WN4A0_WD-WCC6Y6PUS3S8
pvesm add lvm hdd-backup --vgname backup --nodes live-laugh-nicolekidman --content rootdir,images
```

Both copies are in the same house, so they don't cover losing the house.

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
- **Tofu ignores a guest's node, and a container's root disk storage, once they exist.** Both force a rebuild in the provider when they change, so a migrated or failed-over guest, or a container disk moved to other storage, would otherwise plan a destroy. Move guests with `pct migrate`/`qm migrate` or HA, and container disks with `pct move-volume`, not by editing the config. Home Assistant's disks aren't ignored: after `qm disk move`, update their `datastore_id` in `homeassistant.tf` and check the plan is clean.
- **GPU and tun passthrough and the media bind mounts are done by Ansible, not Tofu**: they need `root@pam`, and Tofu uses an API token. The module ignores `device_passthrough` and `mount_point` changes for the same reason.
- **Docker in an LXC** (the arr container) relies on nesting and has broken after Proxmox updates before, usually over AppArmor. If containers stop starting after an upgrade, check `journalctl -u docker` in the container first.
- **Changing the LXC template** won't rebuild existing containers; the module ignores template changes. Tofu downloads the template to every node (`proxmox_download_file.debian_13` in `locals.tf`), so bump its URL and checksum to change it.
- **Tailscale OAuth scope errors** show up as 404s, not 403s.
- **Home Assistant**'s guest agent reports internal interfaces with changing MACs, so `mac_addresses` is ignored.


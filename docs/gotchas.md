# Gotchas

- **Containers use Pi-hole for DNS** (`dns_servers = local.pihole_ips`) because the host's `resolv.conf` points at Tailscale's resolver, which containers can't reach.
- **Rejoining Tailscale**: the auth key is single-use and expires an hour after creation. Mint a fresh one with `tofu -chdir=stacks/tailnet apply -replace='tailscale_tailnet_key.subnet_router["<node>"]'`, then rerun Ansible.
- **Tofu ignores a guest's node, and a container's root disk storage, once they exist.** Both force a rebuild in the provider when they change, so a migrated or failed-over guest, or a container disk moved to other storage, would otherwise plan a destroy. Move guests with `pct migrate`/`qm migrate` or HA, and container disks with `pct move-volume`, not by editing the config. Home Assistant's disks aren't ignored: after `qm disk move`, update their `datastore_id` in `homeassistant.tf` and check the plan is clean.
- **GPU and tun passthrough and the media bind mounts are done by Ansible, not Tofu**: they need `root@pam`, and Tofu uses an API token. The module ignores `device_passthrough` and `mount_point` changes for the same reason.
- **Docker in an LXC** (the arr container) relies on nesting and has broken after Proxmox updates before, usually over AppArmor. If containers stop starting after an upgrade, check `journalctl -u docker` in the container first.
- **Changing the LXC template** won't rebuild existing containers; the module ignores template changes. Tofu downloads the template to every node (`proxmox_download_file.debian_13` in `locals.tf`), so bump its URL and checksum to change it.
- **Tailscale OAuth scope errors** show up as 404s, not 403s.
- **Home Assistant**'s guest agent reports internal interfaces with changing MACs, so `mac_addresses` is ignored.

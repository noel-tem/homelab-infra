# community.proxmox.proxmox_pct_remote, made fast enough that a task doesn't take ~6 seconds:
# - pipelining sends each module over stdin in one exec, instead of separate execs to make a temp dir, upload, run and clean up
# - lxc-attach instead of pct exec, which runs the same thing behind a Perl wrapper that takes ~0.7s to start
from __future__ import annotations

from ansible_collections.community.proxmox.plugins.connection import proxmox_pct_remote

# Same options as the parent; Ansible reads them from this module's DOCUMENTATION when it loads the plugin
DOCUMENTATION = proxmox_pct_remote.DOCUMENTATION.replace("name: proxmox_pct_remote", "name: pct", 1)


class Connection(proxmox_pct_remote.Connection):
    has_pipelining = True

    def _build_pct_command(self, cmd: str) -> str:
        # What pct exec runs; it also fails the same way when the container isn't running on this node
        return " ".join(["/usr/bin/lxc-attach", "-n", str(self.get_option("vmid")), "--keep-env", "--", cmd])

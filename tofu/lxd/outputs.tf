output "worker_ips" {
  value = { for w in lxd_instance.worker : w.name => w.ipv4_address }
}

output "control_plane_ips" {
  value = { for cp in lxd_instance.control_plane : cp.name => cp.ipv4_address }
}

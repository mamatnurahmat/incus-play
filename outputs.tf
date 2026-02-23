output "instance_name" {
  value = [incus_instance.dmz.name, incus_instance.app.name, incus_instance.db.name, incus_instance.rke2_master.name, incus_instance.rke2_agent.name]
}

output "instance_ip" {
  value = [incus_instance.dmz.ipv4_address, incus_instance.app.ipv4_address, incus_instance.db.ipv4_address, incus_instance.rke2_master.ipv4_address, incus_instance.rke2_agent.ipv4_address]
}

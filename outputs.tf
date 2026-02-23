output "instance_name" {
  value = incus_instance.ubuntu_vm.name
}

output "instance_ip" {
  value = incus_instance.ubuntu_vm.ipv4_address
}

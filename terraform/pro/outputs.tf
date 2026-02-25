output "instance_names" {
  description = "List of created instance names"
  value       = [for instance in incus_instance.node : instance.name]
}

output "instance_ips" {
  description = "List of created instance IP addresses"
  value       = [for instance in incus_instance.node : instance.ipv4_address]
}

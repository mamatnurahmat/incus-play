# Incus Terraform & Ansible Setup

This project automates the provisioning of virtual machines using Incus and configures them with Ansible.

## Architecture

- **Hypervisor/Container Manager**: Incus
- **OS Image**: Ubuntu 22.04 LTS (Cloud image)
- **Network**: `incusbr0` (Bridge, `10.0.0.1/24`) with NAT enabled.
- **Instances**:
  - **DMZ**: `10.0.0.10`
  - **APP**: `10.0.0.11`
  - **DB**: `10.0.0.12`

All instances are automatically provisioned with:
- An `ubuntu` user with passwordless `sudo`.
- `openssh-server` installed.
- Your local SSH public key (`~/.ssh/id_rsa.pub`) added to `authorized_keys` via `cloud-init` for passwordless login.

## Requirements

1. **Incus** installed and configured on the host.
2. **Terraform** CLI installed.
3. The **Incus Terraform Provider** (`lxc/incus`) installed locally (if not available in the public registry).
4. **Ansible** installed for configuration management.

## Usage

### 1. Provision Infrastructure with Terraform

Initialize the Terraform working directory and download the provider:
```bash
terraform init
```

Review the planned infrastructure changes:
```bash
terraform plan
```

Apply the configuration to create the network and VMs:
```bash
terraform apply
```

To view the generated output (VM names and IP addresses):
```bash
terraform output
```

### 2. Configure VMs with Ansible

After the VMs are provisioned, use the Ansible playbook to install Docker Engine and Docker Compose.

Change to the ansible directory:
```bash
cd ansible
```

Run the playbook:
```bash
ansible-playbook -i inventory.ini install-docker.yml
```

This playbook will:
1. Update `apt` packages.
2. Add the official Docker GPG key and APT repository.
3. Install Docker Engine, containerd, and Docker Compose plugins.
4. Ensure the Docker service is running.
5. Add the `ubuntu` user to the `docker` group, allowing you to run docker commands without `sudo`.

### SSH Access

You can directly access any of the VMs using the `ubuntu` user:
```bash
ssh ubuntu@10.0.0.10  # For DMZ
ssh ubuntu@10.0.0.11  # For APP
ssh ubuntu@10.0.0.12  # For DB
```

## Setup & Maintenance

For detailed instructions on how to install and setup Incus and the Incus Web UI on different Host OS (like Arch/CachyOS and Ubuntu), please see the separate guide: 
👉 [**Incus Installation Guide**](INCUS_INSTALLATION.md)

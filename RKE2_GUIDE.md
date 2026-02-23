# RKE2 Cluster Setup Guide

This guide explains how to deploy a 2-node RKE2 (Rancher Kubernetes Engine 2) cluster on Incus VMs using Terraform and Ansible.

## Nodes Architecture
- **Master Node**: `rke2-master01` (10.0.0.21) - 4GB RAM
- **Agent Node**: `rke2-agent01` (10.0.0.22) - 2GB RAM

---

## Step 1: Provision Infrastructure
Ensure your Terraform environment is up to date and the new nodes are created.

```bash
cd ~/terraform
terraform apply -auto-approve
```

Verify that you can SSH into both nodes using the `ubuntu` user:
```bash
ssh ubuntu@10.0.0.21
ssh ubuntu@10.0.0.22
```

---

## Step 2: Install RKE2 Master
The master node must be configured first because it generates a `node-token` required by the agents.

```bash
cd ~/terraform/ansible
ansible-playbook -i rke2_inventory.ini 01_rke2_master.yml
```

**What this does:**
1. Installs RKE2 server binary.
2. Starts the `rke2-server` service.
3. Configures local `kubectl` access for the `ubuntu` user.
4. Downloads the cluster token to a local file named `rke2_token` on your machine.

---

## Step 3: Install RKE2 Agent
Once the Master is ready, run the agent playbook.

```bash
ansible-playbook -i rke2_inventory.ini 02_rke2_agent.yml
```

**What this does:**
1. Installs RKE2 agent binary.
2. Reads the `rke2_token` created in Step 2.
3. Configures the agent to connect to `https://10.0.0.21:9345`.
4. Starts the `rke2-agent` service.

---

## Step 4: Verify Cluster Status
Login to the Master node to verify that all nodes have joined and are `Ready`.

```bash
ssh ubuntu@10.0.0.21
```

Once inside the VM, run:
```bash
kubectl get nodes
```

**Example Output:**
```text
NAME             STATUS   ROLES                       AGE   VERSION
rke2-agent01     Ready    <none>                      2m    v1.30.x+rke2r1
rke2-master01    Ready    control-plane,etcd,master   5m    v1.30.x+rke2r1
```

---

## Troubleshooting
If the Master service fails to start, the playbook `01_rke2_master.yml` is configured to dump the `journalctl` logs. Common issues include:
- **Insufficient RAM**: RKE2 Master needs at least 4GB.
- **Port Conflict**: Ensure ports 6443 and 9345 are not taken.
- **Kernel Support**: Ensure the Incus VM has necessary modules (standard Ubuntu 22.04 image is usually fine).

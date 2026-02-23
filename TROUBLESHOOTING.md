# Troubleshooting — Incus on CachyOS

Catatan issue yang sudah ditemukan dan di-solve saat menjalankan Incus di CachyOS.

---

## Daftar Issue

| # | Issue | Penyebab | Status |
|---|-------|----------|--------|
| 1 | [Container/VM tidak dapat IPv4 dari DHCP](#issue-1--containervm-tidak-dapat-ipv4-dari-dhcp) | UFW Firewall memblokir DHCP traffic | ✅ Solved |

---

## Issue 1 — Container/VM tidak dapat IPv4 dari DHCP

**Tanggal**: 23 Februari 2026  
**Environment**: CachyOS (Arch-based), Incus, UFW active  
**Network**: `incusbr0` (bridge, managed, `10.157.148.1/24`)

### Gejala

- Container berstatus **RUNNING** tapi kolom **IPv4 kosong** di `incus list`
- NetworkManager di dalam container stuck di status **"connecting (getting IP configuration)"**
- `dhclient` mengirim **DHCPDISCOVER** berulang kali tanpa response

```
$ incus list
+--------+---------+------+------+-----------+-----------+
|  NAME  |  STATE  | IPV4 | IPV6 |   TYPE    | SNAPSHOTS |
+--------+---------+------+------+-----------+-----------+
| test   | RUNNING |      |      | CONTAINER | 0         |
+--------+---------+------+------+-----------+-----------+

$ incus exec test -- nmcli device status
DEVICE  TYPE      STATE                                  CONNECTION
eth0    ethernet  connecting (getting IP configuration)  System eth0

$ incus exec test -- journalctl -u NetworkManager | tail
dhclient[241]: DHCPDISCOVER on eth0 to 255.255.255.255 port 67 interval 3
dhclient[241]: DHCPDISCOVER on eth0 to 255.255.255.255 port 67 interval 5
dhclient[241]: DHCPDISCOVER on eth0 to 255.255.255.255 port 67 interval 10
```

### Diagnosa

Langkah-langkah diagnosa yang dilakukan:

#### 1. Cek network bridge — ✅ OK
```bash
incus network show incusbr0
# config:
#   ipv4.address: 10.157.148.1/24
#   ipv4.dhcp: "true"
#   ipv4.nat: "true"
# status: Created
```

#### 2. Cek dnsmasq DHCP server — ✅ OK
```bash
ps aux | grep dnsmasq
# dnsmasq --keep-in-foreground ... --interface=incusbr0
#   --listen-address=10.157.148.1
#   --dhcp-range 10.157.148.2,10.157.148.254,1h
```

#### 3. Cek IP forwarding — ✅ OK
```bash
cat /proc/sys/net/ipv4/ip_forward
# 1
```

#### 4. Cek VLAN filtering — ✅ OK
```bash
bridge vlan show
# incusbr0       1 PVID Egress Untagged
# veth2ddc1cf2   1 PVID Egress Untagged   ← container veth
```

#### 5. Cek network config di container — ✅ OK
```bash
incus exec test -- cat /etc/sysconfig/network-scripts/ifcfg-eth0
# DEVICE=eth0
# BOOTPROTO=dhcp
# ONBOOT=yes
```

#### 6. Cek UFW firewall — ❌ MASALAH DITEMUKAN
```bash
sudo ufw status verbose
# Status: active
# Default: deny (incoming), allow (outgoing), deny (routed)
```

**Default policy `deny (incoming)` dan `deny (routed)` memblokir DHCP broadcast traffic (port 67/68) antara container dan bridge `incusbr0`, sehingga dnsmasq tidak pernah menerima DHCPDISCOVER dari container.**

### Penyebab

**UFW (Uncomplicated Firewall)** pada CachyOS aktif secara default dengan policy yang memblokir semua traffic masuk dan routed. Ini menyebabkan:

1. DHCP request (broadcast dari container ke `255.255.255.255:67`) di-drop oleh UFW sebelum sampai ke dnsmasq
2. Bahkan jika DHCP berhasil, traffic antar-container (routed) juga akan di-block karena default `deny (routed)`

### Solusi

Tambahkan UFW rules untuk mengizinkan semua traffic pada interface bridge Incus:

```bash
# Untuk incusbr0 (default bridge)
sudo ufw allow in on incusbr0
sudo ufw allow out on incusbr0
sudo ufw route allow in on incusbr0
sudo ufw route allow out on incusbr0
```

> **Catatan**: Ulangi untuk setiap bridge Incus yang digunakan, contoh:

```bash
# Untuk public-br0
sudo ufw allow in on public-br0
sudo ufw allow out on public-br0
sudo ufw route allow in on public-br0
sudo ufw route allow out on public-br0

# Untuk devops-br0
sudo ufw allow in on devops-br0
sudo ufw allow out on devops-br0
sudo ufw route allow in on devops-br0
sudo ufw route allow out on devops-br0
```

Setelah menambahkan rules, restart NetworkManager di container:

```bash
incus exec <container-name> -- systemctl restart NetworkManager
```

### Verifikasi

```bash
# Cek container mendapat IP
$ incus list
+--------+---------+-----------------------+------+-----------+-----------+
|  NAME  |  STATE  |         IPV4          | IPV6 |   TYPE    | SNAPSHOTS |
+--------+---------+-----------------------+------+-----------+-----------+
| test   | RUNNING | 10.157.148.203 (eth0) |      | CONTAINER | 0         |
+--------+---------+-----------------------+------+-----------+-----------+

# Cek DHCP leases
$ incus network list-leases incusbr0
+----------+-------------------+----------------+---------+
| HOSTNAME |    MAC ADDRESS    |   IP ADDRESS   |  TYPE   |
+----------+-------------------+----------------+---------+
| test     | 10:66:6a:c8:9b:04 | 10.157.148.203 | DYNAMIC |
+----------+-------------------+----------------+---------+

# Cek konektivitas internet dari container
$ incus exec test -- ping -c 3 8.8.8.8
3 packets transmitted, 3 received, 0% packet loss
```

### Pencegahan

Untuk setup baru, jalankan perintah UFW allow **sebelum** membuat container/VM:

```bash
#!/bin/bash
# Jalankan setelah membuat network bridge baru
BRIDGE_NAME="incusbr0"  # ganti sesuai nama bridge

sudo ufw allow in on "${BRIDGE_NAME}"
sudo ufw allow out on "${BRIDGE_NAME}"
sudo ufw route allow in on "${BRIDGE_NAME}"
sudo ufw route allow out on "${BRIDGE_NAME}"

echo "UFW rules untuk ${BRIDGE_NAME} sudah ditambahkan"
sudo ufw status numbered
```

> **Tips**: Rules UFW bersifat **persistent** — tetap aktif setelah reboot, tidak perlu dijalankan ulang.

---

## Referensi Cepat

### Perintah Diagnosa Network

```bash
# Status network Incus
incus network list
incus network show <network-name>
incus network info <network-name>
incus network list-leases <network-name>

# Status network di host
ip addr show <bridge-name>
bridge vlan show

# DHCP server
ps aux | grep dnsmasq

# Firewall
sudo ufw status verbose
sudo ufw status numbered

# Kernel parameters
cat /proc/sys/net/ipv4/ip_forward
sysctl net.ipv4.conf.all.forwarding

# Network di container
incus exec <name> -- ip addr show
incus exec <name> -- nmcli device status
incus exec <name> -- systemctl status NetworkManager
```

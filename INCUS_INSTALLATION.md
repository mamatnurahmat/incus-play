# Installing Incus & Incus UI

This guide details the process of installing Incus and the Incus Web UI on different Linux distributions.

## On CachyOS / Arch Linux
Incus is available in the official Arch Linux repositories.

```bash
# Install Incus and the Incus UI
sudo pacman -Sy incus incus-ui-canonical

# Add your user to the incus-admin group (so you don't need sudo for incus commands)
sudo usermod -aG incus-admin $USER

# Enable and start the Incus service
sudo systemctl enable --now incus.service

# Apply the group change without logging out
newgrp incus-admin

# Initialize Incus (you can simply press Enter to accept the default prompts)
incus admin init
```

## On Ubuntu (22.04 LTS / 24.04 LTS)
For Ubuntu, you should use the official Zabbly repository provided by the Incus maintainers.

```bash
# Install prerequisite packages
sudo apt-get update
sudo apt-get install -y curl apt-transport-https

# Add the repository key and source list
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://pkgs.zabbly.com/info@zabbly.com.asc.key | sudo gpg --dearmor -o /etc/apt/keyrings/zabbly.gpg
echo "deb [signed-by=/etc/apt/keyrings/zabbly.gpg] https://pkgs.zabbly.com/incus/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/zabbly-incus-stable.list

# Install Incus and the UI
sudo apt-get update
sudo apt-get install -y incus incus-ui-canonical

# Add your user to the incus-admin group
sudo usermod -aG incus-admin $USER

# Apply the group change without logging out
newgrp incus-admin

# Initialize Incus
incus admin init
```

## Accessing the Incus UI
Once `incus-ui-canonical` is installed, you need to expose the Incus API to the network to access the web panel:

```bash
# Listen on all IP addresses on port 8443
incus config set core.https_address [::]:8443
```

You can then open the Web UI in your browser at:
`https://<YOUR-HOST-IP>:8443`

*(Note: Since it uses a self-signed certificate, your browser will warn you. You need to proceed past the warning. You will also need to provide valid client certificates to authenticate, which the UI will prompt you to configure).*

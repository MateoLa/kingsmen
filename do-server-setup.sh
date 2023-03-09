#!/bin/bash
set -euo pipefail

### Variables

# Name of the user to create and grant sudo privileges
USERNAME=mateo
HOSTNAME=$(curl -s http://169.254.169.254/metadata/v1/hostname)
PUBLIC_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)

# Whether to copy over the root `authorized_keys` file to the new user
COPY_AUTHORIZED_KEYS_FROM_ROOT=true

# Additional public keys to add to the new user
OTHER_PUBLIC_KEYS_TO_ADD=(
)

### Script

# Lock the root account to password-based access
passwd --lock root

# Add sudo user and grant privileges
useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

# Remove the user's password so that a new password can be set without suppling a previous one
passwd --delete "${USERNAME}"

# Expire the user's password immediately to force a change
chage --lastday 0 "${USERNAME}"

# Create SSH directory for sudo user
home_directory="$(eval echo ~${USERNAME})"
mkdir --parents "${home_directory}/.ssh"

# Copy `authorized_keys` file from root if requested
if [ "${COPY_AUTHORIZED_KEYS_FROM_ROOT}" = true ]; then
    cp /root/.ssh/authorized_keys "${home_directory}/.ssh"
fi

# Add additional provided public keys
for pub_key in "${OTHER_PUBLIC_KEYS_TO_ADD[@]}"; do
    echo "${pub_key}" >> "${home_directory}/.ssh/authorized_keys"
done

# Adjust SSH configuration ownership and permissions
chmod 0700 "${home_directory}/.ssh"
chmod 0600 "${home_directory}/.ssh/authorized_keys"
chown --recursive "${USERNAME}":"${USERNAME}" "${home_directory}/.ssh"

# Disable root SSH login with password
# sed --in-place 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
# if sshd -t -q; then
#    systemctl restart sshd
# fi

# Install nginx
apt-get -y update
apt-get -y install nginx
echo Droplet: $HOSTNAME, IP Address: $PUBLIC_IPV4 > /var/www/html/index.html

# Add exception for SSH and then enable UFW firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Pull Project
Github_Origin="git@github.com:MateoLa/${HOSTNAME}.git"
cd $home_directory
mkdir $HOSTNAME
cd $HOSTNAME
git init
git branch -m main
git remote add origin $Github_Origin
git pull origin main
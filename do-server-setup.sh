#!/bin/bash
set -euo pipefail

########################
### SCRIPT VARIABLES ###
########################

# Name of the user to create and grant sudo privileges
USERNAME=mateo

# Whether to copy over the root user's `authorized_keys` file to the new sudo
# user.
COPY_AUTHORIZED_KEYS_FROM_ROOT=true

# Additional public keys to add to the new sudo user
OTHER_PUBLIC_KEYS_TO_ADD=(
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDGn+TCu5HKhdbMSWFBCGP2Nh9Hz9USmWhQ4ZdKcwRyqKm/6mnLIr3MBgZwvMJrMRSxaNEBX4PJcmO64RUoovyBcbjjjDLPjPNVHnG5ve2zJMJzYtzMahX6IxQl2S1xEjG4W1CStmCehyu2lhYdILGbm+HBJj4lMLWn5KVNrqiFNSWW7rpFgmKIF7u11qRUVgkzBUOle9aBvi2UkhkaBuABG3OTw3Jv2ROCdZtx/iA4rrwv7dyotLdMZWq4xbc0+LW3gYK0f/HJ/3ZYQywo8qgtSSR48W8682yUtwbVIEyPrl6cNsnaVnPcwiyaEmrynjCFGbVM+7mNa/BpmyIXmnRIVaaOayiZmc4UpjHVTjlU6zw7+p5SP8vY+AlQgk8UkddeoV404ilxbSerTwNvvzGQZpb7Q0wkm5kkm1tfcOqYuJ7ns3Nj3aaoIRioImQ81lBneVv9/i4JGd9WPe13utPHzBLLJTQm4dnvwSvNPor57JXfegyJ5/+S7C4avwdo1h0Lef5MGH6iprod2vQoDovYKyZVnyzu78FzepTDCa9tNGaGWfexQJKILHJpq9jLJoCuG2r4jlmThzm/Df2ede3hxvPT0EIHFvt+cnQkXTM+C+Rl/WT697Eeyb4Ka5IJZL8LIAmQHjHxlQWNFKy6SV5alQNfyAjChccMbSaMEb3BQ== ntdom1\c510268@u1704773"
)

####################
### SCRIPT LOGIC ###
####################

# Add sudo user and grant privileges
useradd --create-home --shell "/bin/bash" --groups sudo,docker "${USERNAME}"

# Check whether the root account has a real password set
encrypted_root_pw="$(grep root /etc/shadow | cut --delimiter=: --fields=2)"

if [ "${encrypted_root_pw}" != "*" ]; then
    # Transfer auto-generated root password to user if present
    # and lock the root account to password-based access
    echo "${USERNAME}:${encrypted_root_pw}" | chpasswd --encrypted
    passwd --lock root
else
    # Delete invalid password for user if using keys so that a new password
    # can be set without providing a previous value
    passwd --delete "${USERNAME}"
fi

# Expire the sudo user's password immediately to force a change
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
sed --in-place 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
if sshd -t -q; then
    systemctl restart sshd
fi

# Add exception for SSH and then enable UFW firewall
ufw allow OpenSSH
ufw --force enable
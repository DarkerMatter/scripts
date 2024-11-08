#!/bin/bash
#FTS General Setup Script


# Update and upgrade the system
apt update && apt upgrade -y

# Prompt for hostname
read -p "Enter the hostname for the machine: " hostname

# Set the hostname
hostnamectl set-hostname "$hostname"

# Install required packages
apt install -y docker.io docker-compose fail2ban ufw sudo

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Create a new user 'dimitri' with no password
adduser --disabled-password --gecos "" dimitri

# Grant 'dimitri' sudo privileges
usermod -aG sudo dimitri

# Allow 'dimitri' to run sudo commands without a password (using sudoers.d)
echo "dimitri ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/dimitri > /dev/null

# Ensure the correct permissions for the sudoers file
sudo chmod 0440 /etc/sudoers.d/dimitri

# Add the SSH public key to the new user's authorized keys
mkdir -p /home/dimitri/.ssh
cat << 'EOF' > /home/dimitri/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzZAPtSvvMKWX0mz+ia7g0oe+EqYPjNmDAPTpjXghOWSJfJutN+V9aHzwjDQ4YUzUm1qWdNervop8tECwtUM/w/CksBPvKEZ8IMCxTYhPtYtRlKfz/+kVuZeuTDMipIo0BEA5VJ4O5cjroVdX/tHpmJ04bw2uRJlVy+JEudZ4bBX+XXY2HcnbQciDE8+lepu7CN9hDycsXuV/aQIixxvXpnXn4iFryl5Pi7Ybz6/drABKCrHR2YluwiPioama9Y2O5Z5WMQCnGsUEOuM0HF8w+1PIPhi4alEKp+yDfPdPZ2hq+6K+9vGoBCfzHNo0XVR44ZOmanp42iNzVrQM4Qe2q+WzwRx9r/wsjV2jHBFz6wfMygBvjilNuN+xwWjZ2cbDvjrHQfISWFLwwTcOG2CYqWcWLE/KZKhsl4QPY0fMpd7vkL66MiXRnGb8B2IWR/e3n+fNH4AgQDv8VCdlpUse3gzJt5z6KunjbSwLASRVCriisEZk0Hu3GrbsDgQZEeOxbRiFddIUIPjiCNUj2kx4xq/OuktUSebBnE30tAfU/Mky79hAqeaLViP6Eu+jJEBRyaeDClCO9l6pBFckG8mDmNh3WZMcNtvYKVtlLK4bXrGD7hScEYO2M5kOGyHaYSOw0LD0LhctCarWubTWK3jC3K/+m02FoqlzMJy9dGvIIcw== dimitri@dimitrishepherd.com
EOF

# Set permissions for the .ssh directory and authorized_keys file
chown -R dimitri:dimitri /home/dimitri/.ssh
chmod 700 /home/dimitri/.ssh
chmod 600 /home/dimitri/.ssh/authorized_keys

# Modify /etc/ssh/sshd_config to disable root login and password authentication
sudo bash -c "cat > /etc/ssh/sshd_config" << 'EOF'
# Disable root login and password authentication
PermitRootLogin no
PasswordAuthentication no
EOF

# Restart SSH service
systemctl restart ssh

# Set up UFW (Uncomplicated Firewall)
ufw allow OpenSSH
ufw --force enable  # Automatically proceed without prompting

# Fail2Ban configuration
cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
EOF

# Restart Fail2Ban service
systemctl restart fail2ban

# Notify user
echo "Setup complete! The user 'dimitri' has been created with sudo permissions."

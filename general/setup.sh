#!/bin/bash
#FTS General Setup Script


# Update and upgrade the system
apt update && apt upgrade -y

# Prompt for hostname
read -p "Enter the hostname for the machine: " hostname

# Set the hostname
hostnamectl set-hostname "$hostname"

# Install required packages
apt install -y docker.io docker-compose fail2ban ufw sudo neofetch

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
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCEGjzaZoBtJxWKzigG4BgmlSH/ZmsluVq8Dzp96/9eF1gjAYBga98dGrGocHJ08Tnvk0FVsSdJgcbkdJQFN6ye7ta4reiY2o+0iNGvuABw10/egpysIK7uQWpick6pLkMWQXdq/16f31TLZycVouawjnkzoLRyA21VoCyA4P0ofR7FamhXoNg3h73yQjggsV5PDK1Oa1E9rW35a4C904HLFgB3IiZo+Xgo0q6yvnj/38fov7Lh4UU3VhmGYgHiQsaYAS9p0CDdzaIShACb/j8tW6M5FOKtoywa1zPX294Bt3Ao807xBGr4MtSIuIFZ9tvCrjJOO/xixbRQJJAPdOxj rsa-key-20250722

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
neofetch

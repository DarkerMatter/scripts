#!/bin/bash

# Function to generate a random string of specified length
generate_random_string() {
    local length=$1
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Function to generate a valid username
generate_valid_db_username() {
    local username
    username=$(generate_random_string 30)
    # Ensure it doesn't start with a digit
    while [[ $username =~ ^[0-9] ]]; do
        username=$(generate_random_string 30)
    done
    echo "$username"
}

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

# Allow 'dimitri' to run sudo commands without a password
echo "dimitri ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Add the SSH public key to the new user's authorized keys
mkdir -p /home/dimitri/.ssh
cat << 'EOF' > /home/dimitri/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCEGjzaZoBtJxWKzigG4BgmlSH/ZmsluVq8Dzp96/9eF1gjAYBga98dGrGocHJ08Tnvk0FVsSdJgcbkdJQFN6ye7ta4reiY2o+0iNGvuABw10/egpysIK7uQWpick6pLkMWQXdq/16f31TLZycVouawjnkzoLRyA21VoCyA4P0ofR7FamhXoNg3h73yQjggsV5PDK1Oa1E9rW35a4C904HLFgB3IiZo+Xgo0q6yvnj/38fov7Lh4UU3VhmGYgHiQsaYAS9p0CDdzaIShACb/j8tW6M5FOKtoywa1zPX294Bt3Ao807xBGr4MtSIuIFZ9tvCrjJOO/xixbRQJJAPdOxj rsa-key-20250722
EOF

# Set permissions for the .ssh directory and authorized_keys file
chown -R dimitri:dimitri /home/dimitri/.ssh
chmod 700 /home/dimitri/.ssh
chmod 600 /home/dimitri/.ssh/authorized_keys

# Configure SSH to allow only key authentication and restrict root login
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

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

# Generate random username and password
db_username=$(generate_valid_db_username)
db_password=$(generate_random_string 72)

# Generate random database name
db_name=$(generate_valid_db_username)

# Generate random root password for MySQL
root_password=$(generate_random_string 72)

# Get server's IP address
server_ip=$(hostname -I | awk '{print $1}')

# Create a Docker network for MySQL
docker network create mysql_network

# Run MySQL in Docker
docker run -d \
    --name mysql_container \
    --network mysql_network \
    -e MYSQL_ROOT_PASSWORD="$root_password" \
    -e MYSQL_USER="$db_username" \
    -e MYSQL_PASSWORD="$db_password" \
    -e MYSQL_DATABASE="$db_name" \
    -p 3306:3306 \
    mysql:latest

# Wait for MySQL to initialize
sleep 10

# Grant all privileges on the database to the user as root
docker exec -it mysql_container mysql -u"root" -p"$root_password" -e "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '$db_username'@'%';"

# Allow MySQL access through the firewall
ufw allow 3306/tcp  # Allow MySQL

# Output credentials
echo "MySQL Credentials:"
echo "Username: $db_username"
echo "Password: $db_password"
echo "Root Password: $root_password"  # Output the generated root password
echo "Database Name: $db_name"
echo "Server IP: $server_ip"

# Notify user
echo "Setup complete! The user 'dimitri' has been created with sudo permissions, and the chosen database is running in a Docker container."

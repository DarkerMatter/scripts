#!/bin/bash

# A robust setup script for modern Ubuntu LTS (22.04, 24.04, and newer).
#
# This script performs the following actions:
# 1. Updates the system.
# 2. Sets the hostname.
# 3. Installs Docker and the Docker Compose plugin using the official script.
# 4. Creates a new sudo user with passwordless sudo access.
# 5. Configures SSH for key-based authentication only (disables root and password login).
# 6. Sets up UFW (firewall) and Fail2Ban for basic security.
#
# To run:
# curl -sL <URL_TO_THIS_SCRIPT> -o setup.sh
# chmod +x setup.sh
# sudo ./setup.sh

# Exit immediately if a command exits with a non-zero status.
set -e

# --- SCRIPT FUNCTIONS ---

# Function to check if the script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root. Please use sudo." >&2
        exit 1
    fi
}

# Function to set the system hostname
set_hostname() {
    read -p "Enter the desired hostname for this machine: " hostname
    if [[ -z "$hostname" ]]; then
        echo "Hostname cannot be empty. Exiting." >&2
        exit 1
    fi
    echo "--> Setting hostname to '$hostname'..."
    hostnamectl set-hostname "$hostname"
    echo "--> Hostname set."
}

# Function to install Docker Engine and Compose plugin
install_docker() {
    echo "--> Installing Docker and Docker Compose plugin..."
    # Use the official convenience script from Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    # Start and enable the Docker service
    systemctl start docker
    systemctl enable docker
    echo "--> Docker installed and enabled."
}

# Function to install other essential packages
install_packages() {
    echo "--> Installing Fail2Ban, UFW, and Neofetch..."
    apt-get update
    apt-get install -y fail2ban ufw neofetch
    echo "--> Essential packages installed."
}

# Function to create and configure a new user
setup_user() {
    read -p "Enter the username for the new sudo user: " new_user
    if [[ -z "$new_user" ]]; then
        echo "Username cannot be empty. Exiting." >&2
        exit 1
    fi

    if id "$new_user" &>/dev/null; then
        echo "User '$new_user' already exists. Skipping user creation."
    else
        echo "--> Creating user '$new_user'..."
        # Create user without a password, as they will use SSH keys
        adduser --disabled-password --gecos "" "$new_user"
        usermod -aG sudo "$new_user"
        # Also add user to the docker group to manage docker without sudo
        usermod -aG docker "$new_user"
        echo "--> User '$new_user' created and added to sudo and docker groups."

        echo "--> Granting passwordless sudo rights to '$new_user'..."
        # Create a sudoers file for the new user
        echo "$new_user ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$new_user"
        chmod 0440 "/etc/sudoers.d/$new_user"
        echo "--> Sudo rights configured."
    fi

    echo "--> Setting up SSH access for '$new_user'..."
    read -p "Paste the SSH public key for '$new_user': " ssh_public_key
    if [[ -z "$ssh_public_key" ]]; then
        echo "SSH public key cannot be empty. Exiting." >&2
        exit 1
    fi

    local ssh_dir="/home/$new_user/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    mkdir -p "$ssh_dir"
    echo "$ssh_public_key" > "$auth_keys_file"

    # Set correct permissions
    chown -R "$new_user:$new_user" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys_file"
    echo "--> SSH public key added for '$new_user'."
}

# Function to harden SSH configuration
configure_ssh() {
    echo "--> Hardening SSH configuration..."
    local sshd_config="/etc/ssh/sshd_config"

    # Disable root login
    sed -i 's/^#?PermitRootLogin.*/PermitRootLogin no/g' "$sshd_config"

    # Disable password authentication
    sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication no/g' "$sshd_config"
    
    # Ensure ChallengeResponseAuthentication is also disabled
    sed -i 's/^#?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/g' "$sshd_config"

    # Restart SSH to apply changes
    systemctl restart ssh
    echo "--> SSH configuration hardened and service restarted."
}

# Function to set up the firewall and Fail2Ban
configure_security() {
    echo "--> Configuring Firewall (UFW)..."
    ufw allow OpenSSH
    # Use --force to enable without interactive prompts
    ufw --force enable
    echo "--> UFW enabled and configured to allow SSH."

    echo "--> Configuring Fail2Ban..."
    cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF
    systemctl restart fail2ban
    echo "--> Fail2Ban configured and restarted."
}

# --- MAIN EXECUTION ---

main() {
    check_root
    echo "Starting General Server Setup for Ubuntu LTS..."
    
    apt-get update && apt-get upgrade -y
    
    set_hostname
    install_packages
    install_docker
    setup_user
    configure_ssh
    configure_security
    
    echo ""
    echo "=================================================="
    echo "          Server setup is complete!               "
    echo "=================================================="
    echo "You should now be able to log in as the new user via SSH."
    echo ""
    
    neofetch
}

# Run the main function
main

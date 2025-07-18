#!/bin/bash
# =============================================================================
# UBUNTU 24.04 PATCH APPLICATION SCRIPT
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ROLE_DIR="roles/slurm_master"
BACKUP_DIR="ubuntu-24.04-patch-backup-$(date +%Y%m%d_%H%M%S)"

# Logging
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -d "$ROLE_DIR" ]]; then
        error "Role directory $ROLE_DIR not found!"
        error "Please run this script from the project root directory"
        exit 1
    fi
    
    log "Found role directory: $ROLE_DIR"
}

# Create backup
create_backup() {
    log "Creating backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -r "$ROLE_DIR" "$BACKUP_DIR/"
    success "Backup created successfully"
}

# Function to patch a file
patch_file() {
    local file_path="$1"
    local patch_content="$2"
    local description="$3"
    
    if [[ ! -f "$file_path" ]]; then
        warning "File $file_path not found, skipping..."
        return 0
    fi
    
    log "Patching $description: $file_path"
    
    # Create backup of original file
    cp "$file_path" "$file_path.backup-$(date +%Y%m%d_%H%M%S)"
    
    # Apply patch (this is simplified - in real scenario you'd use more sophisticated patching)
    echo "$patch_content" >> "$file_path"
    
    success "Patched $description"
}

# Main patching functions
patch_defaults() {
    log "Patching defaults/main.yml..."
    
    cat >> "$ROLE_DIR/defaults/main.yml" << 'EOF'

# =============================================================================
# UBUNTU 24.04 COMPATIBILITY SETTINGS
# =============================================================================

# Cgroup plugin selection based on Ubuntu version
slurm_cgroup_plugin: "{{ 'cgroup/v2' if (ansible_distribution == 'Ubuntu' and ansible_distribution_version is version('24.04', '>=')) else 'cgroup/v1' }}"

# Python version for Ubuntu 24.04
slurm_python_version: "{{ '3.12' if (ansible_distribution == 'Ubuntu' and ansible_distribution_version is version('24.04', '>=')) else '3.10' }}"

# MariaDB version
slurm_mariadb_version: "{{ '10.11' if (ansible_distribution == 'Ubuntu' and ansible_distribution_version is version('24.04', '>=')) else '10.6' }}"

# Package lists for different Ubuntu versions
slurm_packages_ubuntu_24_04:
  - build-essential
  - libmunge-dev
  - libmunge2
  - munge
  - libmysqlclient-dev
  - mysql-server
  - mysql-client
  - libssl-dev
  - libpam0g-dev
  - libnuma-dev
  - libhwloc-dev
  - libperl-dev
  - liblua5.3-dev
  - libreadline-dev
  - librrd-dev
  - libncurses5-dev
  - libhttpparser-dev  # Changed for Ubuntu 24.04
  - libjson-c-dev
  - libcurl4-openssl-dev
  - python3.12-dev     # Specific version for Ubuntu 24.04
  - python3.12-pip     # Specific version for Ubuntu 24.04
  - python3.12-venv    # New requirement for Ubuntu 24.04
  - python3.12-full    # Full Python installation

slurm_packages_ubuntu_default:
  - build-essential
  - libmunge-dev
  - libmunge2
  - munge
  - libmysqlclient-dev
  - mysql-server
  - mysql-client
  - libssl-dev
  - libpam0g-dev
  - libnuma-dev
  - libhwloc-dev
  - libperl-dev
  - liblua5.3-dev
  - libreadline-dev
  - librrd-dev
  - libncurses5-dev
  - libhttp-parser-dev  # Original name
  - libjson-c-dev
  - libcurl4-openssl-dev
  - python3-dev
  - python3-pip

# SystemD security enhancements for Ubuntu 24.04
slurm_systemd_security_ubuntu_24_04: true
EOF

    success "Patched defaults/main.yml"
}

patch_packages() {
    log "Patching tasks/packages.yml..."
    
    # Create a backup
    cp "$ROLE_DIR/tasks/packages.yml" "$ROLE_DIR/tasks/packages.yml.backup"
    
    # Add Ubuntu 24.04 specific package installation
    cat >> "$ROLE_DIR/tasks/packages.yml" << 'EOF'

# =============================================================================
# UBUNTU 24.04 SPECIFIC PACKAGE INSTALLATION
# =============================================================================

- name: "Установка пакетов для Ubuntu 24.04+"
  package:
    name: "{{ slurm_packages_ubuntu_24_04 }}"
    state: present
    update_cache: yes
  when: 
    - ansible_os_family == "Debian"
    - ansible_distribution == "Ubuntu"
    - ansible_distribution_version is version('24.04', '>=')
  tags: [packages, ubuntu, ubuntu-24.04]

- name: "Установка пакетов для Ubuntu < 24.04"
  package:
    name: "{{ slurm_packages_ubuntu_default }}"
    state: present
    update_cache: yes
  when: 
    - ansible_os_family == "Debian"
    - ansible_distribution == "Ubuntu"
    - ansible_distribution_version is version('24.04', '<')
  tags: [packages, ubuntu, ubuntu-legacy]
EOF

    success "Patched tasks/packages.yml"
}

patch_cgroup_conf() {
    log "Patching templates/cgroup.conf.j2..."
    
    if [[ ! -f "$ROLE_DIR/templates/cgroup.conf.j2" ]]; then
        warning "cgroup.conf.j2 not found, skipping..."
        return 0
    fi
    
    # Backup original
    cp "$ROLE_DIR/templates/cgroup.conf.j2" "$ROLE_DIR/templates/cgroup.conf.j2.backup"
    
    # Replace the CgroupPlugin line
    sed -i 's/CgroupPlugin={{ slurm_cgroup_plugin | default.*}}/# Cgroup plugin selection based on Ubuntu version\n{% if ansible_distribution == "Ubuntu" and ansible_distribution_version is version("24.04", ">=") %}\nCgroupPlugin=cgroup\/v2\n{% else %}\nCgroupPlugin={{ slurm_cgroup_plugin | default("cgroup\/v1") }}\n{% endif %}/' "$ROLE_DIR/templates/cgroup.conf.j2"
    
    success "Patched templates/cgroup.conf.j2"
}

patch_systemd_service() {
    log "Patching templates/slurmctld.service.j2..."
    
    if [[ ! -f "$ROLE_DIR/templates/slurmctld.service.j2" ]]; then
        warning "slurmctld.service.j2 not found, skipping..."
        return 0
    fi
    
    # Add Ubuntu 24.04 security settings
    cat >> "$ROLE_DIR/templates/slurmctld.service.j2" << 'EOF'

{% if ansible_distribution == "Ubuntu" and ansible_distribution_version is version('24.04', '>=') %}
# Ubuntu 24.04 additional security settings
LockPersonality=yes
RestrictRealtime=yes
SystemCallArchitectures=native
RestrictNamespaces=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
RemoveIPC=yes
RestrictSUIDSGID=yes
MemoryDenyWriteExecute=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK
ProtectProc=invisible
ProcSubset=pid
PrivateUsers=yes
{% endif %}
EOF

    success "Patched templates/slurmctld.service.j2"
}

patch_jwt_generator() {
    log "Patching templates/jwt_generator.py.j2..."
    
    if [[ ! -f "$ROLE_DIR/templates/jwt_generator.py.j2" ]]; then
        warning "jwt_generator.py.j2 not found, skipping..."
        return 0
    fi
    
    # Backup original
    cp "$ROLE_DIR/templates/jwt_generator.py.j2" "$ROLE_DIR/templates/jwt_generator.py.j2.backup"
    
    # Replace shebang
    sed -i '1c\{% if ansible_distribution == "Ubuntu" and ansible_distribution_version is version("24.04", ">=") %}\n#!/usr/bin/env python3.12\n{% else %}\n#!/usr/bin/env python3\n{% endif %}' "$ROLE_DIR/templates/jwt_generator.py.j2"
    
    success "Patched templates/jwt_generator.py.j2"
}

create_ubuntu_vars() {
    log "Creating vars/ubuntu-24.04.yml..."
    
    mkdir -p "$ROLE_DIR/vars"
    
    cat > "$ROLE_DIR/vars/ubuntu-24.04.yml" << 'EOF'
---
# Ubuntu 24.04 LTS specific variables

# System packages
system_packages_24_04:
  - systemd
  - cgroup-tools
  - cgroupfs-mount

# Python packages  
python_packages_24_04:
  - python3.12-full
  - python3.12-dev
  - python3.12-pip
  - python3.12-venv
  - python3.12-setuptools
  - python3.12-wheel

# Compiler and build tools
build_packages_24_04:
  - gcc-13
  - g++-13
  - make
  - cmake
  - pkg-config

# SSL and crypto
ssl_packages_24_04:
  - libssl3
  - libssl-dev
  - openssl

# Database
database_packages_24_04:
  - mariadb-server
  - mariadb-client
  - libmariadb-dev

# Systemd service defaults for Ubuntu 24.04
systemd_defaults_24_04:
  ProtectSystem: "strict"
  ProtectHome: "yes"
  PrivateTmp: "yes"
  NoNewPrivileges: "yes"
  LockPersonality: "yes"
  RestrictRealtime: "yes"
  SystemCallArchitectures: "native"
  MemoryDenyWriteExecute: "yes"
EOF

    success "Created vars/ubuntu-24.04.yml"
}

# Update main.yml to include Ubuntu 24.04 vars
patch_main_yml() {
    log "Patching tasks/main.yml..."
    
    # Add include_vars at the beginning
    sed -i '1a\
- name: "Загрузка переменных для Ubuntu 24.04"\
  include_vars: "ubuntu-24.04.yml"\
  when: \
    - ansible_distribution == "Ubuntu"\
    - ansible_distribution_version is version("24.04", ">=")\
  tags: [always]\
' "$ROLE_DIR/tasks/main.yml"
    
    success "Patched tasks/main.yml"
}

# Verification function
verify_patches() {
    log "Verifying patches..."
    
    local errors=0
    
    # Check if files exist and contain expected content
    if [[ ! -f "$ROLE_DIR/vars/ubuntu-24.04.yml" ]]; then
        error "ubuntu-24.04.yml not created"
        errors=$((errors + 1))
    fi
    
    if ! grep -q "slurm_packages_ubuntu_24_04" "$ROLE_DIR/defaults/main.yml"; then
        error "defaults/main.yml not properly patched"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -eq 0 ]]; then
        success "All patches applied successfully!"
        return 0
    else
        error "$errors errors found during verification"
        return 1
    fi
}

# Main execution
main() {
    log "Starting Ubuntu 24.04 patch application..."
    
    check_directory
    create_backup
    
    # Apply patches
    patch_defaults
    patch_packages
    patch_cgroup_conf
    patch_systemd_service
    patch_jwt_generator
    create_ubuntu_vars
    patch_main_yml
    
    # Verify
    if verify_patches; then
        success "Ubuntu 24.04 patch applied successfully!"
        echo
        echo "Next steps:"
        echo "1. Review the changes in $ROLE_DIR"
        echo "2. Test with: ansible-playbook --syntax-check"
        echo "3. Run in check mode: ansible-playbook --check"
        echo "4. Test on Ubuntu 24.04 system"
        echo
        echo "Backup created in: $BACKUP_DIR"
    else
        error "Some patches failed to apply correctly"
        echo "Check the backup in: $BACKUP_DIR"
        exit 1
    fi
}

# Run main function
main "$@"

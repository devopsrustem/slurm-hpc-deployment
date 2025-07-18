#!/bin/bash
#
# setup.sh - Установка Ansible и зависимостей для slurm-hpc-deployment
#
# Использование: ./scripts/setup.sh
#

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Проверка ОС
check_os() {
    info "Проверка операционной системы..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        info "Обнаружена ОС: $OS $VER"
        
        case $ID in
            ubuntu)
                if [[ "$VERSION_ID" != "22.04" && "$VERSION_ID" != "20.04" ]]; then
                    warning "Рекомендуется Ubuntu 22.04 LTS. Текущая версия: $VERSION_ID"
                fi
                ;;
            centos|rhel)
                warning "CentOS/RHEL поддерживается экспериментально"
                ;;
            *)
                warning "Неизвестная ОС. Продолжаем на свой страх и риск..."
                ;;
        esac
    else
        error "Не удалось определить операционную систему"
    fi
}

# Проверка Python
check_python() {
    info "Проверка Python..."
    
    if ! command -v python3 &> /dev/null; then
        error "Python3 не найден. Установите Python 3.8+"
    fi
    
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    info "Обнаружен Python: $PYTHON_VERSION"
    
    # Проверка минимальной версии Python (3.8+)
    if ! python3 -c 'import sys; exit(0 if sys.version_info >= (3,8) else 1)'; then
        error "Требуется Python 3.8+. Текущая версия: $PYTHON_VERSION"
    fi
}

# Установка pip и базовых пакетов
install_pip() {
    info "Проверка pip..."
    
    if ! command -v pip3 &> /dev/null; then
        info "Установка pip..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y python3-pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3-pip
        else
            error "Не удалось установить pip. Установите вручную."
        fi
    fi
    
    # Обновление pip
    info "Обновление pip..."
    python3 -m pip install --user --upgrade pip
}

# Установка системных зависимостей
install_system_deps() {
    info "Установка системных зависимостей..."
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        sudo apt-get update -qq
        sudo apt-get install -y \
            curl \
            wget \
            git \
            ssh \
            sshpass \
            python3-dev \
            python3-setuptools \
            python3-wheel \
            build-essential \
            libssl-dev \
            libffi-dev \
            libxml2-dev \
            libxslt1-dev \
            zlib1g-dev
            
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        sudo yum install -y \
            curl \
            wget \
            git \
            openssh-clients \
            sshpass \
            python3-devel \
            python3-setuptools \
            gcc \
            openssl-devel \
            libffi-devel \
            libxml2-devel \
            libxslt-devel \
            zlib-devel
    else
        warning "Неизвестный менеджер пакетов. Установите зависимости вручную."
    fi
}

# Установка Ansible
install_ansible() {
    info "Установка Ansible..."
    
    # Проверка существующей установки
    if command -v ansible &> /dev/null; then
        ANSIBLE_VERSION=$(ansible --version | head -n1 | cut -d' ' -f3 | cut -d']' -f1 | tr -d '[')
        info "Ansible уже установлен: $ANSIBLE_VERSION"
        
        # Проверка минимальной версии (2.15+)
        if ! python3 -c "import packaging.version; exit(0 if packaging.version.parse('$ANSIBLE_VERSION') >= packaging.version.parse('2.15.0') else 1)" 2>/dev/null; then
            warning "Обновление Ansible до последней версии..."
            python3 -m pip install --user --upgrade ansible
        fi
    else
        info "Установка Ansible через pip..."
        python3 -m pip install --user ansible
    fi
    
    # Проверка установки
    if ! command -v ansible &> /dev/null; then
        warning "Ansible не найден в PATH. Добавьте ~/.local/bin в PATH:"
        echo "export PATH=\$PATH:~/.local/bin" >> ~/.bashrc
        export PATH=$PATH:~/.local/bin
    fi
    
    success "Ansible установлен: $(ansible --version | head -n1)"
}

# Установка Ansible коллекций
install_collections() {
    info "Установка Ansible коллекций..."
    
    if [[ -f requirements.yml ]]; then
        ansible-galaxy collection install -r requirements.yml --force
        success "Коллекции установлены"
    else
        warning "Файл requirements.yml не найден. Пропускаем установку коллекций."
    fi
}

# Создание рабочих директорий
setup_directories() {
    info "Создание рабочих директорий..."
    
    # Создание tmp директории для Ansible
    mkdir -p tmp/ansible_facts_cache
    
    # Создание config директории если не существует
    if [[ ! -d config ]]; then
        mkdir -p config
        info "Создана директория config/"
    fi
    
    # Копирование примера инвентори
    if [[ -f config/inventory.example && ! -f config/inventory ]]; then
        cp config/inventory.example config/inventory
        info "Скопирован пример инвентори в config/inventory"
        warning "Отредактируйте config/inventory под ваш кластер!"
    fi
}

# Проверка SSH ключей
check_ssh_keys() {
    info "Проверка SSH ключей..."
    
    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        warning "SSH ключ не найден в ~/.ssh/id_ed25519"
        echo
        echo "Для автоматической аутентификации создайте SSH ключ:"
        echo "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
        echo "  ssh-copy-id saadmin@target-host"
        echo
    else
        success "SSH ключ найден: ~/.ssh/id_ed25519"
    fi
}

# Финальная проверка
final_check() {
    info "Финальная проверка установки..."
    
    # Проверка Ansible
    if ! command -v ansible &> /dev/null; then
        error "Ansible не установлен или не найден в PATH"
    fi
    
    # Проверка ansible-playbook
    if ! command -v ansible-playbook &> /dev/null; then
        error "ansible-playbook не найден"
    fi
    
    # Проверка конфигурации
    if [[ -f ansible.cfg ]]; then
        success "Найден ansible.cfg"
    else
        warning "ansible.cfg не найден"
    fi
    
    success "Установка завершена успешно!"
}

# Вывод справки по использованию
show_usage() {
    echo
    echo "==========================="
    echo "  СЛЕДУЮЩИЕ ШАГИ"
    echo "==========================="
    echo
    echo "1. Отредактируйте инвентори:"
    echo "   vim config/inventory"
    echo
    echo "2. Настройте переменные кластера:"
    echo "   vim config/group_vars/slurm_cluster.yml"
    echo
    echo "3. Скопируйте SSH ключ на все хосты:"
    echo "   ssh-copy-id saadmin@sm02"
    echo "   ssh-copy-id saadmin@sm03"
    echo "   ssh-copy-id saadmin@cn01"
    echo "   # и т.д. для всех хостов"
    echo
    echo "4. Проверьте подключение к хостам:"
    echo "   ansible all -m ping"
    echo
    echo "5. Запустите установку:"
    echo "   ansible-playbook playbooks/site.yml"
    echo
    echo "Документация: docs/installation.md"
    echo
}

# Основная функция
main() {
    echo "======================================"
    echo "  SLURM HPC DEPLOYMENT SETUP"
    echo "======================================"
    echo
    
    check_os
    check_python
    install_pip
    install_system_deps
    install_ansible
    install_collections
    setup_directories
    check_ssh_keys
    final_check
    
    show_usage
}

# Запуск скрипта
main "$@"
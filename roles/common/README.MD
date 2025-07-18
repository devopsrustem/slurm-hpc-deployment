# Ansible Role: common

Базовая роль для подготовки системы к установке Slurm HPC кластера.

## Описание

Эта роль выполняет базовую настройку всех узлов кластера:

- Обновление системных пакетов
- Установка инструментов разработки и компиляции
- Создание пользователей и групп для Slurm и MUNGE
- Создание необходимой структуры директорий
- Оптимизация системных параметров для HPC
- Настройка окружения пользователей

## Требования

- Ubuntu 20.04+ 
- Ansible 2.15+
- Пользователь с sudo правами

## Переменные роли

### Основные переменные

```yaml
# Пользователи и группы
slurm_user: "slurm"
slurm_group: "slurm"
slurm_uid: 981
slurm_gid: 981

munge_user: "munge"
munge_group: "munge"
munge_uid: 982
munge_gid: 982

# Директории
slurm_prefix: "/opt/slurm"
slurm_spool_dir: "/var/spool/slurm"
slurm_log_dir: "/var/log/slurm"

# Системные настройки
timezone: "UTC"
update_system_packages: true
reboot_after_kernel_update: false
```

### Пакеты

```yaml
# Базовые пакеты
base_packages:
  - curl
  - wget
  - git
  # ... и другие

# Пакеты для компиляции
build_packages:
  - build-essential
  - gcc
  - make
  # ... и другие

# Библиотеки разработки
dev_libraries:
  - libssl-dev
  - libffi-dev
  # ... и другие
```

### Производительность

```yaml
# Sysctl настройки
sysctl_settings:
  "net.core.rmem_max": "134217728"
  "vm.swappiness": "1"
  # ... и другие

# Лимиты пользователей
limits_settings:
  - domain: "*"
    type: "soft"
    item: "nofile"
    value: "65536"
  # ... и другие
```

## Использование

### В playbook

```yaml
- hosts: slurm_cluster
  become: yes
  roles:
    - common
```

### С переменными

```yaml
- hosts: slurm_cluster
  become: yes
  roles:
    - role: common
      vars:
        timezone: "Europe/Moscow"
        update_system_packages: true
        reboot_after_kernel_update: false
```

### Только определенные задачи

```yaml
- hosts: slurm_cluster
  become: yes
  roles:
    - role: common
      tags:
        - packages
        - users
```

## Доступные теги

- `info` - Информационные сообщения
- `validation` - Проверки системы
- `packages` - Установка пакетов
- `users` - Создание пользователей
- `directories` - Создание директорий
- `system` - Системные настройки
- `environment` - Настройка окружения
- `performance` - Оптимизация производительности

## Примеры

### Минимальная установка

```bash
ansible-playbook -l slurm_cluster playbook.yml --tags "packages,users,directories"
```

### Полная настройка

```bash
ansible-playbook -l slurm_cluster playbook.yml
```

### Только системная оптимизация

```bash
ansible-playbook -l slurm_cluster playbook.yml --tags "system,performance"
```

### Обновление пакетов

```bash
ansible-playbook -l slurm_cluster playbook.yml --tags "packages" -e "update_system_packages=true"
```

## Результат выполнения

После успешного выполнения роли:

1. **Пользователи созданы**: `slurm` (UID: 981), `munge` (UID: 982)
2. **Директории готовы**: `/opt/slurm`, `/etc/slurm`, `/var/log/slurm`, и т.д.
3. **Пакеты установлены**: компиляторы, библиотеки, инструменты разработки
4. **Система оптимизирована**: sysctl, limits, отключен swap
5. **Окружение настроено**: PATH, aliases, профили пользователей

## Валидация

Роль включает встроенные проверки:

- Проверка поддерживаемой ОС
- Валидация созданных пользователей
- Проверка установленных пакетов
- Валидация созданных директорий
- Проверка системных настроек

## Зависимости

Эта роль не имеет зависимостей от других ролей, но должна выполняться перед:

- `slurm_master`
- `slurm_compute`
- `slurm_login`
- `enroot`
- `pyxis`

## Автор

Создано для проекта slurm-hpc-deployment
R.N Valitov

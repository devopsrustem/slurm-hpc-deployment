slurm-hpc-deployment
Современное развертывание HPC кластера с Slurm 25.05.1 на базе Ubuntu 22.04.
🎯 Особенности

Slurm 25.05.1 с поддержкой JWT аутентификации
Enroot 3.5.0 + Pyxis 0.20.0 для контейнеров
Оптимизация для DGX H100 и больших кластеров (64+ нод)
Modular design - устанавливайте только нужные компоненты
Ubuntu 22.04 LTS поддержка

🏗️ Архитектура
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────────────┐
│   sm02 (master) │    │  sm03 (login)   │    │     cn[01-64] (compute)         │
│                 │    │                 │    │                                 │
│ • slurmctld     │◄──►│ • slurm clients │    │ • slurmd                        │
│ • slurmdbd      │    │ • ssh access    │    │ • enroot + pyxis                │
│ • mysql         │    │ • user tools    │    │ • GPU detection                 │
│ • slurmrestd    │    │                 │    │ • cgroups                       │
│ • jwt keys      │    │                 │    │ • node health check            │
└─────────────────┘    └─────────────────┘    └─────────────────────────────────┘
🚀 Быстрый старт
1. Установка зависимостей
bash# Клонирование репозитория
git clone <repository-url> slurm-hpc-deployment
cd slurm-hpc-deployment

# Установка Ansible и зависимостей
./scripts/setup.sh

# Установка коллекций Ansible
ansible-galaxy install -r requirements.yml
2. Конфигурация
bash# Копирование примера инвентори
cp config/inventory.example config/inventory

# Редактирование инвентори для вашего кластера
vim config/inventory

# Настройка переменных кластера
vim config/group_vars/slurm_cluster.yml
3. Развертывание
bash# Полное развертывание кластера
ansible-playbook playbooks/site.yml

# Или поэтапно:
ansible-playbook playbooks/prerequisites.yml    # Подготовка системы
ansible-playbook playbooks/slurm_cluster.yml    # Установка Slurm
ansible-playbook playbooks/containers.yml       # Enroot + Pyxis
ansible-playbook playbooks/jwt_setup.yml        # JWT аутентификация
4. Валидация
bash# Проверка состояния кластера
ansible-playbook playbooks/validation.yml

# Или используйте скрипт
./scripts/validate_cluster.sh
📁 Структура проекта
slurm-hpc-deployment/
├── config/                  # Конфигурационные файлы
├── playbooks/              # Ansible плейбуки
├── roles/                  # Ansible роли
├── scripts/                # Вспомогательные скрипты
├── tests/                  # Тесты и валидация
└── docs/                   # Документация
🔧 Компоненты
КомпонентВерсияОписаниеSlurm25.05.1Планировщик задач с JWT поддержкойEnroot3.5.0Контейнерная платформа для HPCPyxis0.20.0SPANK plugin для интеграции контейнеровMySQL8.0+База данных для slurmdbdMUNGELatestАутентификация между узлами
📋 Требования
Системные требования

OS: Ubuntu 22.04 LTS
Ansible: >= 2.15.0
Python: >= 3.8
SSH: Passwordless доступ к всем узлам

Минимальная конфигурация

1x Master node: 4 CPU, 8GB RAM, 50GB диск
1x Login node: 2 CPU, 4GB RAM, 20GB диск
2+ Compute nodes: Любая конфигурация с GPU

Рекомендуемая конфигурация (наша цель)

sm02 (master): 8+ CPU, 32GB+ RAM, 200GB+ SSD
sm03 (login): 4+ CPU, 16GB+ RAM, 100GB+ SSD
cn[01-64] (compute): DGX H100 с InfiniBand 400Gb/s

🔐 Безопасность

JWT токены для REST API аутентификации
MUNGE для inter-node коммуникации
TLS encryption для Slurm RPC (опционально)
Role-based управление доступом

📚 Документация

Installation Guide - Детальное руководство по установке
Configuration Guide - Настройка кластера
JWT Setup - Настройка JWT аутентификации
Container Guide - Работа с Enroot + Pyxis
Troubleshooting - Решение проблем

🧪 Тестирование
bash# Запуск базовых тестов
ansible-playbook tests/integration/test_slurm_basic.yml

# Тестирование контейнеров
ansible-playbook tests/integration/test_containers.yml

# Тестирование JWT
ansible-playbook tests/integration/test_jwt_auth.yml
🔄 Обновление
bash# Обновление конфигурации
ansible-playbook playbooks/utilities/update_config.yml

# Перезапуск сервисов
ansible-playbook playbooks/utilities/restart_slurm.yml
🤝 Contributing

Fork проект
Создайте feature branch
Commit изменения
Push в branch
Создайте Pull Request

📝 License
MIT License - см. LICENSE файл
🆘 Support

Issues: Создавайте GitHub Issues для багов и feature requests
Discussions: Используйте GitHub Discussions для вопросов
Documentation: Проверьте docs/ для детальной информации


Версия: 1.0.0-dev
Поддерживаемые ОС: Ubuntu 22.04 LTS
Тестировано на: DGX H100 clusters
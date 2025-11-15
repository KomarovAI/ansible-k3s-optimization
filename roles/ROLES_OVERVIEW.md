roles:
  # system_optimization - Оптимизация системы, sysctl, limits, zram и ускорение I/O
  # ssh_security - Жёсткое усиление SSH (смена порта, ограничения логинов, OnlyKey)
  # fail2ban - Защита SSH/honeypot, интеграция c ipset, гибкая фильтрация auth-логов
  # honeypot - Мульти-порт ловушка, автоматическая блокировка, логирование атакующих
  # ipset - Высокопроизводительный blacklist, интеграция с fail2ban/honeypot
  # xt_recent - Защита rate limiting для SSH и port scans
  # psad - Детектирование сканирования портов, бан по уровню угрозы
  # arpwatch - ARP spoofing detection, алерты об изменении MAC-адресов
  # kernel_security - Настройка син cookies, conntrack, AppArmor, ограничений ядра
  # k3s_audit - Интеграция полного bash-скрипта аудита, cron, ротация логов

  # Все роли документированы в каталоге roles/*/README.md (добавить описание если отсутствует)
  # Каждый playbook содержит комментарии к основным блокам и переменным

#!/usr/bin/env bash
#
# install_dev_tools.sh
# -----------------------------------------------------------------------------
# Автоматичне встановлення інструментів розробника:
#   * Docker (Docker Engine)
#   * Docker Compose (плагін `docker compose`)
#   * Python 3 (версія 3.9 або новіша)
#   * Django (через pip)
#
# Скрипт ІДЕМПОТЕНТНИЙ: перед встановленням кожного інструмента він перевіряє,
# чи той вже присутній у системі, тож повторний запуск не дублює встановлення.
#
# Підтримувані ОС: Ubuntu / Debian (менеджер пакетів apt).
#
# Використання:
#   chmod u+x install_dev_tools.sh
#   ./install_dev_tools.sh
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# ----------------------------- Налаштування ----------------------------------
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=9
LOG_PREFIX="[install_dev_tools]"

# ----------------------------- Допоміжні функції -----------------------------
log()  { printf '\033[1;34m%s\033[0m %s\n'   "$LOG_PREFIX"   "$*"; }
ok()   { printf '\033[1;32m%s ✔\033[0m %s\n' "$LOG_PREFIX"   "$*"; }
warn() { printf '\033[1;33m%s ⚠\033[0m %s\n' "$LOG_PREFIX"   "$*" >&2; }
err()  { printf '\033[1;31m%s ✘\033[0m %s\n' "$LOG_PREFIX"   "$*" >&2; }

# Чи доступна команда?
have() { command -v "$1" >/dev/null 2>&1; }

# Обгортка для прав root: якщо вже root — без sudo, інакше через sudo.
SUDO=""
setup_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  elif have sudo; then
    SUDO="sudo"
  else
    err "Потрібні права root або встановлений 'sudo'."
    exit 1
  fi
}

# Перевірка, що ми на системі з apt.
require_apt() {
  if ! have apt-get; then
    err "Скрипт підтримує лише системи на базі Debian/Ubuntu (apt-get не знайдено)."
    exit 1
  fi
}

# Поточний користувач (надійно, навіть якщо $USER не заданий).
current_user() { echo "${SUDO_USER:-${USER:-$(id -un)}}"; }

# Оновлюємо індекс apt лише один раз за запуск.
APT_UPDATED=0
apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    log "Оновлюю індекс пакетів apt..."
    $SUDO apt-get update -y
    APT_UPDATED=1
  fi
}

# ----------------------------- Python ----------------------------------------
python_version_ok() {
  have python3 || return 1
  python3 - "$PYTHON_MIN_MAJOR" "$PYTHON_MIN_MINOR" <<'PY'
import sys
need = (int(sys.argv[1]), int(sys.argv[2]))
sys.exit(0 if sys.version_info[:2] >= need else 1)
PY
}

ensure_pip() {
  if python3 -m pip --version >/dev/null 2>&1; then
    return
  fi
  log "Встановлюю pip (python3-pip)..."
  apt_update_once
  $SUDO apt-get install -y python3-pip
}

install_python() {
  if python_version_ok; then
    ok "Python вже встановлено: $(python3 --version 2>&1) (потрібно >= ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR})."
  else
    log "Встановлюю Python ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR}+..."
    apt_update_once
    $SUDO apt-get install -y python3 python3-pip python3-venv
    if ! python_version_ok; then
      err "Встановлена версія Python нижча за ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR}."
      exit 1
    fi
    ok "Python встановлено: $(python3 --version 2>&1)"
  fi
  ensure_pip
}

# ----------------------------- Django ----------------------------------------
install_django() {
  if python3 -c 'import django' >/dev/null 2>&1; then
    ok "Django вже встановлено: $(python3 -m django --version 2>/dev/null)."
    return
  fi

  log "Встановлюю Django через pip (у середовище користувача)..."
  ensure_pip

  # Встановлюємо для поточного користувача (--user), без sudo.
  # Ubuntu 24.04+ позначає системне середовище як externally-managed (PEP 668),
  # тому за потреби додаємо --break-system-packages як запасний варіант.
  if ! python3 -m pip install --user --upgrade django >/dev/null 2>&1; then
    warn "Виявлено externally-managed середовище (PEP 668) — повторюю з --break-system-packages."
    python3 -m pip install --user --upgrade --break-system-packages django
  fi

  # Робимо встановлені користувацькі скрипти доступними у цьому сеансі.
  export PATH="$HOME/.local/bin:$PATH"

  if python3 -c 'import django' >/dev/null 2>&1; then
    ok "Django встановлено: $(python3 -m django --version 2>/dev/null)"
  else
    err "Не вдалося встановити Django."
    exit 1
  fi
}

# ----------------------------- Docker ----------------------------------------
install_docker() {
  if have docker; then
    ok "Docker вже встановлено: $(docker --version)"
  else
    log "Встановлюю Docker Engine з офіційного репозиторію Docker..."
    apt_update_once
    $SUDO apt-get install -y ca-certificates curl

    # Додаємо офіційний GPG-ключ Docker.
    $SUDO install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
      $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
      $SUDO chmod a+r /etc/apt/keyrings/docker.asc
    fi

    # Додаємо apt-репозиторій Docker для поточної версії Ubuntu.
    local arch codename
    arch="$(dpkg --print-architecture)"
    codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")"
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
      | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

    # Примусово оновлюємо індекс (з'явилось нове джерело).
    $SUDO apt-get update -y
    APT_UPDATED=1

    # docker-compose-plugin одразу дає команду `docker compose`.
    $SUDO apt-get install -y \
      docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin

    ok "Docker встановлено: $(docker --version)"
  fi

  post_install_docker
}

post_install_docker() {
  local user
  user="$(current_user)"

  # Додаємо користувача до групи docker, щоб працювати без sudo.
  if getent group docker >/dev/null 2>&1; then
    if ! id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
      $SUDO usermod -aG docker "$user" || true
      warn "Користувача '$user' додано до групи 'docker'. Перезайдіть у сесію або виконайте 'newgrp docker', щоб зміни набули чинності."
    fi
  fi

  # Намагаємось увімкнути та запустити демон Docker (де це можливо).
  if have systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^docker\.service'; then
    $SUDO systemctl enable docker >/dev/null 2>&1 || true
    $SUDO systemctl start  docker >/dev/null 2>&1 || true
  elif have service; then
    $SUDO service docker start >/dev/null 2>&1 || true
  fi
}

# ----------------------------- Docker Compose --------------------------------
install_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    ok "Docker Compose (плагін) вже доступний: $(docker compose version)"
    return
  fi
  if have docker-compose; then
    ok "Docker Compose (standalone) вже встановлено: $(docker-compose --version)"
    return
  fi

  log "Встановлюю плагін Docker Compose..."
  apt_update_once
  $SUDO apt-get install -y docker-compose-plugin

  if docker compose version >/dev/null 2>&1; then
    ok "Docker Compose встановлено: $(docker compose version)"
  else
    err "Не вдалося встановити Docker Compose."
    exit 1
  fi
}

# ----------------------------- Підсумок --------------------------------------
summary() {
  echo
  log "Підсумок (перевірка версій):"
  printf '  %-16s %s\n' "Docker:"         "$(docker --version 2>/dev/null || echo 'НЕ встановлено')"
  printf '  %-16s %s\n' "Docker Compose:" "$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo 'НЕ встановлено')"
  printf '  %-16s %s\n' "Python:"         "$(python3 --version 2>/dev/null || echo 'НЕ встановлено')"
  printf '  %-16s %s\n' "Django:"         "$(python3 -m django --version 2>/dev/null || echo 'НЕ встановлено')"
  echo
}

# ----------------------------- main ------------------------------------------
main() {
  log "Старт встановлення інструментів розробника..."
  require_apt
  setup_sudo

  install_python
  install_django
  install_docker
  install_docker_compose

  summary
  ok "Готово! Усі інструменти перевірено/встановлено."
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "Arquivo obrigatório ausente: $file"
  pass "Arquivo presente: $file"
}

check_executable_or_warn() {
  local file="$1"
  if [[ -x "$file" ]]; then
    pass "Executável: $file"
  else
    warn "Sem +x (pode ser intencional dependendo de como o Calamares invoca): $file"
  fi
}

check_bash_syntax() {
  local file="$1"
  bash -n "$file" || fail "Erro de sintaxe Bash: $file"
  pass "Sintaxe Bash OK: $file"
}

printf '== ClariceOS smoke test ==\n'

# 1) Estrutura mínima do projeto
require_file "README.md"
require_file "build.sh"
require_file "releng/profiledef.sh"
require_file "releng/packages.x86_64"
require_file "releng/customize_airootfs.sh"
require_file "releng/pacman.conf"
require_file "releng/airootfs/etc/calamares/settings.conf"
require_file "releng/airootfs/etc/calamares/netinstall.yaml"
require_file "releng/airootfs/etc/calamares/scripts/configure-de.sh"
require_file "releng/airootfs/etc/calamares/scripts/install-bootloader.sh"
require_file "releng/airootfs/usr/share/plymouth/themes/clariceos/clariceos.plymouth"
require_file "releng/airootfs/usr/share/plymouth/themes/clariceos/clariceos.script"

# 2) Scripts críticos válidos para execução
check_bash_syntax "build.sh"
check_bash_syntax "releng/customize_airootfs.sh"
check_bash_syntax "releng/airootfs/etc/calamares/scripts/configure-de.sh"
check_bash_syntax "releng/airootfs/etc/calamares/scripts/install-bootloader.sh"
check_bash_syntax "releng/airootfs/etc/calamares/scripts/limine-deploy.sh"
check_bash_syntax "releng/airootfs/etc/calamares/scripts/setup-secureboot.sh"

# 3) Sinaliza scripts sem +x (não fatal)
check_executable_or_warn "build.sh"
check_executable_or_warn "releng/customize_airootfs.sh"
check_executable_or_warn "releng/airootfs/etc/calamares/scripts/configure-de.sh"
check_executable_or_warn "releng/airootfs/etc/calamares/scripts/install-bootloader.sh"
check_executable_or_warn "releng/airootfs/etc/calamares/scripts/limine-deploy.sh"
check_executable_or_warn "releng/airootfs/etc/calamares/scripts/setup-secureboot.sh"

printf '== Smoke test concluído com sucesso ==\n'

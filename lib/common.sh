#!/usr/bin/env bash
# Sopardus common library - shared utilities for install.sh phases
# License: GPL-3.0-or-later

# Global configuration
readonly SOPARDUS_VERSION="0.3"
readonly SOPARDUS_STATE_DIR="/etc/sopardus"
readonly SOPARDUS_STATE_FILE="${SOPARDUS_STATE_DIR}/install.state"
readonly SOPARDUS_LOG_DIR="/var/log/sopardus"
readonly SOPARDUS_RELEASE_FILE="/etc/sopardus-release"

# Runtime flags (set by parse_args)
DRY_RUN="false"
ASSUME_YES="false"
NO_SNAPSHOT="false"
PROFILE="desktop"
ENABLE_GAMING="false"
ENABLE_NVIDIA="false"
REMOVE_GNOME="false"
DO_REVERT="false"

# Parsed from preflight
ROOT_FS_TYPE=""
GPU_VENDOR=""
IS_VM="false"
PLASMA_VERSION=""
BTRFS_LAYOUT=""  # A, B, or C per §5.6

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

LOG_FILE=""

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${timestamp} [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "${YELLOW}$*${NC}"; }
log_error() { log "ERROR" "${RED}$*${NC}"; }
log_debug() { [[ "${DEBUG:-false}" == "true" ]] && log "DEBUG" "${BLUE}$*${NC}"; }

die() {
    log_error "$@"
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root (use sudo)"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --yes)
                ASSUME_YES="true"
                shift
                ;;
            --no-snapshot)
                NO_SNAPSHOT="true"
                shift
                ;;
            --gaming)
                ENABLE_GAMING="true"
                shift
                ;;
            --nvidia)
                ENABLE_NVIDIA="true"
                shift
                ;;
            --remove-gnome)
                REMOVE_GNOME="true"
                shift
                ;;
            --revert)
                DO_REVERT="true"
                shift
                ;;
            --profile)
                PROFILE="${2:-}"
                if [[ ! "${PROFILE}" =~ ^(desktop|laptop|gaming)$ ]]; then
                    die "Invalid profile: ${PROFILE}. Use: desktop, laptop, gaming"
                fi
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                die "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done

    if [[ "${REMOVE_GNOME}" == "true" ]]; then
        die "--remove-gnome is not supported in Phase 0 (reserved for Phase 1+)"
    fi

    if [[ "${DO_REVERT}" == "true" && "${DRY_RUN}" == "true" ]]; then
        die "--revert and --dry-run are mutually exclusive"
    fi
}

print_usage() {
    cat <<'EOF'
Sopardus install.sh - Convert Pardus 25.2 GNOME to Sopardus (Plasma 6 Wayland)

Usage: sudo ./install.sh [OPTIONS]

Options:
  --dry-run          Show what would be done without making changes
  --yes              Skip confirmation prompts (except snapshot)
  --no-snapshot      Explicitly skip snapshot (requires --yes)
  --gaming           Install gaming packages (gamemode, mangohud, gamescope, etc.)
  --nvidia           Install NVIDIA proprietary drivers (non-free, Secure Boot/MOK warning)
  --remove-gnome     NOT SUPPORTED IN PHASE 0 (reserved for Phase 1+)
  --revert           Revert changes using saved state
  --profile NAME     Profile: desktop | laptop | gaming (default: desktop)
  -h, --help         Show this help

Examples:
  sudo ./install.sh --dry-run
  sudo ./install.sh --profile laptop --gaming
  sudo ./install.sh --revert
EOF
}

setup_logging() {
    local timestamp
    timestamp="$(date '+%Y%m%d-%H%M%S')"
    LOG_FILE="${SOPARDUS_LOG_DIR}/install-${timestamp}.log"

    if [[ "${DRY_RUN}" == "false" ]]; then
        mkdir -p "${SOPARDUS_LOG_DIR}"
        mkdir -p "${SOPARDUS_STATE_DIR}"
        touch "${LOG_FILE}"
        chmod 644 "${LOG_FILE}"
    fi
}

run_phase() {
    local phase_name="$1"
    local phase_script="$2"

    log_info "=== Phase: ${phase_name} ==="

    if [[ ! -f "${phase_script}" ]]; then
        die "Phase script not found: ${phase_script}"
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: ${phase_script}"
        return 0
    fi

    # shellcheck source=/dev/null
    source "${phase_script}"
    "phase_${phase_name}"

    log_info "=== Phase ${phase_name} complete ==="
}

# State management
state_write() {
    local key="$1"
    local value="$2"
    mkdir -p "${SOPARDUS_STATE_DIR}"
    local tmp_file
    tmp_file="$(mktemp)"
    if [[ -f "${SOPARDUS_STATE_FILE}" ]]; then
        grep -v "^${key}=" "${SOPARDUS_STATE_FILE}" > "${tmp_file}" || true
    else
        > "${tmp_file}"
    fi
    echo "${key}=${value}" >> "${tmp_file}"
    mv "${tmp_file}" "${SOPARDUS_STATE_FILE}"
    chmod 600 "${SOPARDUS_STATE_FILE}"
}

state_read() {
    local key="$1"
    if [[ -f "${SOPARDUS_STATE_FILE}" ]]; then
        grep "^${key}=" "${SOPARDUS_STATE_FILE}" | cut -d'=' -f2- | tail -n1
    fi
}

state_has() {
    local key="$1"
    [[ -f "${SOPARDUS_STATE_FILE}" ]] && grep -q "^${key}=" "${SOPARDUS_STATE_FILE}"
}

# Idempotency checks (real system state, not just state file)
is_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

is_service_enabled() {
    systemctl is-enabled "$1" >/dev/null 2>&1
}

is_service_active() {
    systemctl is-active "$1" >/dev/null 2>&1
}

file_equals() {
    local file1="$1"
    local file2="$2"
    [[ -f "${file1}" && -f "${file2}" ]] && cmp -s "${file1}" "${file2}"
}

backup_file() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        local backup="${file}.sopardus.bak.$(date '+%Y%m%d%H%M%S')"
        cp -p "${file}" "${backup}"
        state_write "backup_$(basename "${file}")" "${backup}"
        log_debug "Backed up ${file} to ${backup}"
    fi
}

restore_file() {
    local file="$1"
    local backup_key="backup_$(basename "${file}")"
    local backup
    backup="$(state_read "${backup_key}")"
    if [[ -n "${backup}" && -f "${backup}" ]]; then
        cp -p "${backup}" "${file}"
        log_info "Restored ${file} from ${backup}"
    else
        log_warn "No backup found for ${file}"
    fi
}

run_cmd() {
    local cmd=("$@")
    log_debug "Running: ${cmd[*]}"
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would run: ${cmd[*]}"
        return 0
    fi
    "${cmd[@]}" 2>&1 | tee -a "${LOG_FILE}"
}

apt_install() {
    local packages=("$@")
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! is_package_installed "${pkg}"; then
            to_install+=("${pkg}")
        else
            log_debug "Package already installed: ${pkg}"
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing packages: ${to_install[*]}"
        run_cmd apt-get update
        run_cmd apt-get install -y --no-install-recommends "${to_install[@]}"
    else
        log_info "All packages already installed"
    fi
}

apt_remove() {
    local packages=("$@")
    local to_remove=()
    for pkg in "${packages[@]}"; do
        if is_package_installed "${pkg}"; then
            to_remove+=("${pkg}")
        fi
    done

    if [[ ${#to_remove[@]} -gt 0 ]]; then
        log_info "Removing packages: ${to_remove[*]}"
        run_cmd apt-get remove -y "${to_remove[@]}"
        run_cmd apt-get autoremove -y
    else
        log_info "No packages to remove"
    fi
}

confirm() {
    local prompt="$1"
    if [[ "${ASSUME_YES}" == "true" ]]; then
        return 0
    fi
    read -rp "${prompt} [y/N] " -n 1
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

print_summary() {
    cat <<EOF

========================================
Sopardus Installation Summary
========================================
Profile: ${PROFILE}
Gaming: ${ENABLE_GAMING}
NVIDIA: ${ENABLE_NVIDIA}
Log: ${LOG_FILE}
State: ${SOPARDUS_STATE_FILE}

Next steps:
  1. Reboot to start Plasma Wayland session
  2. Run 'sopardus doctor' to verify system health
  3. Customize theme via System Settings > Appearance

To revert: sudo ./install.sh --revert

EOF
}
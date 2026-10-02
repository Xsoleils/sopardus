#!/usr/bin/env bash
# Phase 20: Package installation
# License: GPL-3.0-or-later

phase_packages() {
    log_info "Installing Plasma 6 and core packages..."

    install_core_packages

    if [[ "${ENABLE_GAMING}" == "true" ]]; then
        install_gaming_packages
    fi

    if [[ "${ENABLE_NVIDIA}" == "true" ]]; then
        install_nvidia_packages
    fi
}

install_core_packages() {
    local pkg_list="${SCRIPT_DIR}/packages/core.list"
    if [[ ! -f "${pkg_list}" ]]; then
        die "Core package list not found: ${pkg_list}"
    fi

    local packages=()
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue
        packages+=("${line}")
    done < "${pkg_list}"

    log_info "Installing ${#packages[@]} core packages..."
    apt_install "${packages[@]}"

    verify_plasma_installation
}

verify_plasma_installation() {
    local critical=("plasma-desktop" "kwin-wayland" "sddm" "qt6-wayland")
    for pkg in "${critical[@]}"; do
        if ! is_package_installed "${pkg}"; then
            die "Critical package not installed: ${pkg}"
        fi
    done
    log_info "Critical Plasma packages verified"
}

install_gaming_packages() {
    local pkg_list="${SCRIPT_DIR}/packages/gaming.list"
    if [[ ! -f "${pkg_list}" ]]; then
        log_warn "Gaming package list not found: ${pkg_list}"
        return 0
    fi

    local packages=()
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue
        packages+=("${line}")
    done < "${pkg_list}"

    log_info "Installing ${#packages[@]} gaming packages..."
    apt_install "${packages[@]}"
}

install_nvidia_packages() {
    local pkg_list="${SCRIPT_DIR}/packages/nvidia.list"
    if [[ ! -f "${pkg_list}" ]]; then
        log_warn "NVIDIA package list not found: ${pkg_list}"
        return 0
    fi

    log_warn "Installing NVIDIA proprietary drivers (non-free)"
    log_warn "Secure Boot users: You will need to enroll MOK key after reboot"

    local packages=()
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue
        packages+=("${line}")
    done < "${pkg_list}"

    log_info "Installing ${#packages[@]} NVIDIA packages..."
    apt_install "${packages[@]}"

    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd update-initramfs -u
    fi
}
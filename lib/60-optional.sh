#!/usr/bin/env bash
# Phase 60: Optional features (currently minimal - gaming/nvidia handled in packages)
# License: GPL-3.0-or-later

phase_optional() {
    log_info "Running optional configuration..."

    if [[ "${DO_REVERT}" == "true" ]]; then
        revert_optional
        return 0
    fi

    configure_gaming_mode
    configure_nvidia_optimus
    create_sopardus_release
}

configure_gaming_mode() {
    if [[ "${ENABLE_GAMING}" != "true" ]]; then
        return 0
    fi

    log_info "Configuring gaming optimizations..."

    local gamemode_conf="/etc/gamemode.ini"
    if [[ -f "${gamemode_conf}" ]]; then
        backup_file "${gamemode_conf}"
    fi

    cat > "${gamemode_conf}" <<'EOF'
[general]
desiredgov=performance
softrealtime=auto
renice=10
ioprio=0
inhibit_screensaver=1
EOF

    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd systemctl enable --now gamemoded 2>/dev/null || true
    fi
}

configure_nvidia_optimus() {
    if [[ "${ENABLE_NVIDIA}" != "true" || "${GPU_VENDOR}" != "nvidia" ]]; then
        return 0
    fi

    log_info "Configuring NVIDIA Optimus/Prime..."

    local nvidia_conf="/etc/modprobe.d/sopardus-nvidia.conf"
    backup_file "${nvidia_conf}"

    cat > "${nvidia_conf}" <<'EOF'
# Sopardus NVIDIA options
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_UsePageAttributeTable=1
EOF
}

create_sopardus_release() {
    log_info "Creating /etc/sopardus-release..."

    cat > "${SOPARDUS_RELEASE_FILE}" <<EOF
Sopardus ${SOPARDUS_VERSION}
Based on Pardus ${VERSION_ID} (Debian 13 Trixie)
Desktop: KDE Plasma 6 (Wayland)
Profile: ${PROFILE}
Build: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
EOF
}

revert_optional() {
    log_info "Reverting optional configuration..."

    local gamemode_conf="/etc/gamemode.ini"
    if [[ -f "${gamemode_conf}" ]]; then
        rm -f "${gamemode_conf}"
    fi

    local nvidia_conf="/etc/modprobe.d/sopardus-nvidia.conf"
    restore_file "${nvidia_conf}"

    if [[ -f "${SOPARDUS_RELEASE_FILE}" ]]; then
        rm -f "${SOPARDUS_RELEASE_FILE}"
    fi

    run_cmd systemctl disable --now gamemoded 2>/dev/null || true

    log_info "Optional configuration reverted"
}
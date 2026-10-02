#!/usr/bin/env bash
# Phase 30: Session/DM switch (GDM -> SDDM, Wayland default)
# License: GPL-3.0-or-later

phase_session() {
    log_info "Configuring display manager and session..."

    if [[ "${DO_REVERT}" == "true" ]]; then
        revert_session
        return 0
    fi

    configure_sddm
    disable_gdm
    set_wayland_default
    configure_sddm_theme
}

configure_sddm() {
    log_info "Setting SDDM as default display manager..."

    local current_dm
    current_dm="$(debconf-show shared/default-x-display-manager 2>/dev/null | grep 'shared/default-x-display-manager' | cut -d' ' -f3 || echo "unknown")"

    if [[ "${current_dm}" != "sddm" ]]; then
        state_write "previous_dm" "${current_dm}"
        log_info "Previous DM: ${current_dm}"
    else
        log_info "SDDM already default"
    fi

    run_cmd debconf-set-selections <<<'shared/default-x-display-manager select sddm'
    run_cmd DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive sddm
}

disable_gdm() {
    log_info "Disabling GDM..."

    if is_service_enabled gdm3; then
        state_write "gdm_was_enabled" "true"
        run_cmd systemctl disable gdm3
        log_info "GDM disabled"
    else
        state_write "gdm_was_enabled" "false"
        log_info "GDM already disabled"
    fi

    if is_service_active gdm3; then
        run_cmd systemctl stop gdm3
    fi

    run_cmd systemctl enable sddm
    run_cmd systemctl set-default graphical.target
}

set_wayland_default() {
    log_info "Setting Plasma Wayland as default session..."

    local sddm_conf="/etc/sddm.conf.d/sopardus-wayland.conf"
    mkdir -p "$(dirname "${sddm_conf}")"

    cat > "${sddm_conf}" <<'EOF'
[Autologin]
Relogin=false
Session=plasmawayland.desktop
User=

[General]
InputMethod=qtvirtualkeyboard
Numlock=on

[Theme]
Current=breeze

[Wayland]
EnableHiDPI=true
EOF

    state_write "sddm_conf_created" "${sddm_conf}"
}

configure_sddm_theme() {
    log_info "Configuring SDDM theme (Breeze)..."

    local theme_conf="/etc/sddm.conf.d/sopardus-theme.conf"
    cat > "${theme_conf}" <<'EOF'
[Theme]
Current=breeze
CursorTheme=breeze_cursors
EOF
}

revert_session() {
    log_info "Reverting display manager changes..."

    local previous_dm
    previous_dm="$(state_read "previous_dm")"

    if [[ -n "${previous_dm}" && "${previous_dm}" != "unknown" ]]; then
        log_info "Restoring previous DM: ${previous_dm}"
        run_cmd debconf-set-selections <<<"shared/default-x-display-manager select ${previous_dm}"
        run_cmd DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive "${previous_dm}"
    fi

    if [[ "$(state_read "gdm_was_enabled")" == "true" ]]; then
        run_cmd systemctl enable gdm3
    fi

    run_cmd systemctl disable sddm 2>/dev/null || true

    local sddm_conf
    sddm_conf="$(state_read "sddm_conf_created")"
    if [[ -n "${sddm_conf}" && -f "${sddm_conf}" ]]; then
        rm -f "${sddm_conf}"
    fi

    log_info "Session reverted"
}
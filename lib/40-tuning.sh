#!/usr/bin/env bash
# Phase 40: System tuning (zram, fstrim, sysctl, Baloo)
# License: GPL-3.0-or-later

phase_tuning() {
    log_info "Applying system tuning..."

    if [[ "${DO_REVERT}" == "true" ]]; then
        revert_tuning
        return 0
    fi

    configure_zram
    enable_fstrim
    configure_sysctl
    configure_baloo
    configure_power_profiles
}

configure_zram() {
    log_info "Configuring zram (zstd)..."

    local zram_conf="/etc/systemd/zram-generator.conf"
    backup_file "${zram_conf}"

    cat > "${zram_conf}" <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
EOF

    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd systemctl daemon-reload
        run_cmd systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true
    fi
}

enable_fstrim() {
    log_info "Enabling fstrim.timer..."

    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd systemctl enable --now fstrim.timer
    fi
}

configure_sysctl() {
    log_info "Configuring sysctl..."

    local sysctl_conf="/etc/sysctl.d/99-sopardus.conf"
    backup_file "${sysctl_conf}"

    cat > "${sysctl_conf}" <<'EOF'
# Sopardus performance tuning
vm.swappiness = 100
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Network
net.core.netdev_max_backlog = 250000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3

# FS
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF

    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd sysctl --system
    fi
}

configure_baloo() {
    log_info "Configuring Baloo (file indexing - filename only)..."

    local baloo_conf="/etc/xdg/baloofilerc"
    mkdir -p "$(dirname "${baloo_conf}")"
    backup_file "${baloo_conf}"

    cat > "${baloo_conf}" <<'EOF'
[Basic Settings]
Indexing-Enabled=true
only-index-file-names=true
excludeFilters=/tmp/,/var/tmp/,/var/cache/,/var/spool/,*.iso,*.img,*.qcow2,*.vdi,*.vmdk,*.box,/home/*/.cache/,/home/*/.local/share/Trash/,/home/*/VirtualBox VMs/,/home/*/.vagrant.d/,/home/*/node_modules/,/home/*/.gradle/,/home/*/.m2/,/home/*/target/
excludeFiltersVersion=2
firstRun=false
EOF
}

configure_power_profiles() {
    log_info "Configuring power-profiles-daemon..."

    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd systemctl enable --now power-profiles-daemon
    fi

    case "${PROFILE}" in
        laptop)
            log_info "Laptop profile: setting balanced power profile"
            run_cmd powerprofilesctl set balanced 2>/dev/null || true
            ;;
        gaming)
            log_info "Gaming profile: setting performance power profile"
            run_cmd powerprofilesctl set performance 2>/dev/null || true
            ;;
        *)
            log_info "Desktop profile: setting balanced power profile"
            run_cmd powerprofilesctl set balanced 2>/dev/null || true
            ;;
    esac
}

revert_tuning() {
    log_info "Reverting tuning..."

    local zram_conf="/etc/systemd/zram-generator.conf"
    restore_file "${zram_conf}"

    local sysctl_conf="/etc/sysctl.d/99-sopardus.conf"
    if [[ -f "${sysctl_conf}" ]]; then
        rm -f "${sysctl_conf}"
        run_cmd sysctl --system
    fi

    local baloo_conf="/etc/xdg/baloofilerc"
    restore_file "${baloo_conf}"

    run_cmd systemctl disable --now fstrim.timer 2>/dev/null || true
    run_cmd systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true

    log_info "Tuning reverted"
}
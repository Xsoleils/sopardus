#!/usr/bin/env bash
# Phase 10: Snapshot creation (Btrfs + Snapper or fallback)
# License: GPL-3.0-or-later

phase_snapshot() {
    log_info "Creating pre-installation snapshot..."

    if [[ "${NO_SNAPSHOT}" == "true" ]]; then
        log_info "Snapshot skipped (--no-snapshot flag)"
        create_etc_backup
        return 0
    fi

    case "${ROOT_FS_TYPE}" in
        btrfs)
            create_btrfs_snapshot
            ;;
        *)
            log_warn "Root filesystem is ${ROOT_FS_TYPE}, not Btrfs"
            create_etc_backup
            ;;
    esac
}

create_btrfs_snapshot() {
    log_info "Setting up Snapper for Btrfs..."

    if ! command -v snapper >/dev/null 2>&1; then
        log_info "Installing snapper..."
        apt_install snapper
    fi

    case "${BTRFS_LAYOUT}" in
        A)
            create_snapper_config_root
            create_snapshot "pre-sopardus"
            setup_grub_btrfs
            setup_apt_snapper_hook
            ;;
        B)
            log_warn "Btrfs layout B (top-level): Snapper config created but rollout/grub-btrfs boot not guaranteed"
            create_snapper_config_root
            create_snapshot "pre-sopardus"
            create_etc_backup
            ;;
    esac
}

create_snapper_config_root() {
    if snapper -c root get-config >/dev/null 2>&1; then
        log_info "Snapper config 'root' already exists"
        return 0
    fi

    log_info "Creating snapper config for / ..."
    run_cmd snapper -c root create-config /
}

create_snapshot() {
    local description="$1"
    log_info "Creating snapshot: ${description}"
    run_cmd snapper -c root create --description "${description}" --cleanup-algorithm number
}

setup_grub_btrfs() {
    if is_package_installed grub-btrfs; then
        log_info "grub-btrfs already installed"
        return 0
    fi

    log_info "Installing grub-btrfs..."
    apt_install grub-btrfs

    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd systemctl enable --now grub-btrfsd
        run_cmd systemctl enable --now grub-btrfs.path
    fi
}

setup_apt_snapper_hook() {
    local hook_file="/etc/apt/apt.conf.d/80sopardus-snapper"
    if [[ -f "${hook_file}" ]]; then
        log_info "APT snapper hook already exists"
        return 0
    fi

    log_info "Creating APT snapper hook..."
    cat > "${hook_file}" <<'EOF'
DPkg::Pre-Invoke {"snapper -c root create --description 'pre-apt' --cleanup-algorithm number || true"; };
DPkg::Post-Invoke {"snapper -c root create --description 'post-apt' --cleanup-algorithm number || true"; };
EOF
}

create_etc_backup() {
    log_info "Creating /etc backup..."

    local backup_dir="/var/backups/sopardus-preinstall-$(date '+%Y%m%d%H%M%S')"
    run_cmd mkdir -p "${backup_dir}"
    run_cmd rsync -a --exclude='*.bak' --exclude='*.swp' /etc/ "${backup_dir}/"
    state_write "etc_backup" "${backup_dir}"
    log_info "/etc backed up to ${backup_dir}"
}
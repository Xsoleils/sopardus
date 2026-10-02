#!/usr/bin/env bash
# Phase 90: Finalize installation
# License: GPL-3.0-or-later

phase_finalize() {
    log_info "Finalizing installation..."

    if [[ "${DO_REVERT}" == "true" ]]; then
        log_info "Revert complete - system restored to pre-Sopardus state"
        log_info "Please reboot to apply changes"
        return 0
    fi

    update_initramfs
    update_grub
    write_state
    log_completion
}

update_initramfs() {
    log_info "Updating initramfs..."
    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd update-initramfs -u -k all
    fi
}

update_grub() {
    log_info "Updating GRUB..."
    if [[ "${DRY_RUN}" == "false" ]]; then
        run_cmd update-grub
    fi
}

write_state() {
    log_info "Writing installation state..."

    state_write "version" "${SOPARDUS_VERSION}"
    state_write "installed_at" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    state_write "profile" "${PROFILE}"
    state_write "gaming" "${ENABLE_GAMING}"
    state_write "nvidia" "${ENABLE_NVIDIA}"
    state_write "btrfs_layout" "${BTRFS_LAYOUT}"
    state_write "root_fs_type" "${ROOT_FS_TYPE}"
    state_write "gpu_vendor" "${GPU_VENDOR}"
    state_write "is_vm" "${IS_VM}"
    state_write "plasma_version" "${PLASMA_VERSION}"

    log_info "State written to ${SOPARDUS_STATE_FILE}"
}

log_completion() {
    log_info "========================================"
    log_info "Sopardus installation complete!"
    log_info "========================================"
    log_info ""
    log_info "A reboot is required to start Plasma Wayland."
    log_info ""
    log_info "After reboot:"
    log_info "  - Select 'Plasma (Wayland)' at SDDM login"
    log_info "  - Run 'sopardus doctor' to verify system health"
    log_info "  - Customize theme in System Settings > Appearance"
    log_info ""
    log_info "To revert: sudo ./install.sh --revert"
    log_info "Log file: ${LOG_FILE}"
    log_info "State file: ${SOPARDUS_STATE_FILE}"
}
#!/usr/bin/env bash
# Phase 00: Preflight checks
# License: GPL-3.0-or-later

phase_preflight() {
    log_info "Running preflight checks..."

    require_root

    check_os
    check_architecture
    check_disk_space
    check_network
    detect_root_fs
    detect_gpu
    detect_vm
    check_plasma_version
    check_pardus_tools
    confirm_proceed
}

check_os() {
    log_info "Checking OS..."

    if [[ ! -f /etc/os-release ]]; then
        die "Cannot determine OS: /etc/os-release not found"
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    if [[ "${ID}" != "pardus" ]]; then
        die "This script requires Pardus Linux (ID=pardus), found: ${ID}"
    fi

    if [[ ! "${VERSION_ID}" =~ ^25\. ]]; then
        die "This script requires Pardus 25.x, found: ${VERSION_ID}"
    fi

    log_info "OS: ${PRETTY_NAME} (ID=${ID}, VERSION_ID=${VERSION_ID})"
}

check_architecture() {
    local arch
    arch="$(dpkg --print-architecture)"
    if [[ "${arch}" != "amd64" ]]; then
        die "Unsupported architecture: ${arch} (only amd64 supported)"
    fi
    log_info "Architecture: ${arch}"
}

check_disk_space() {
    local available_kb
    available_kb="$(df / | awk 'NR==2 {print $4}')"
    local available_gb=$((available_kb / 1024 / 1024))

    if [[ ${available_gb} -lt 6 ]]; then
        die "Insufficient disk space: ${available_gb} GB available, need at least 6 GB"
    fi

    log_info "Disk space: ${available_gb} GB available on /"
}

check_network() {
    if ! ping -c 1 -W 2 deb.debian.org >/dev/null 2>&1 && \
       ! ping -c 1 -W 2 packages.pardus.org.tr >/dev/null 2>&1; then
        log_warn "Network connectivity test failed - package installation may fail"
    else
        log_info "Network connectivity: OK"
    fi
}

detect_root_fs() {
    log_info "Detecting root filesystem..."

    ROOT_FS_TYPE="$(findmnt -no FSTYPE /)"
    log_info "Root filesystem: ${ROOT_FS_TYPE}"

    if [[ "${ROOT_FS_TYPE}" == "btrfs" ]]; then
        detect_btrfs_layout
    fi
}

detect_btrfs_layout() {
    log_info "Analyzing Btrfs layout..."

    local subvol_info
    subvol_info="$(btrfs subvolume list / 2>/dev/null || true)"

    if echo "${subvol_info}" | grep -q 'path @$'; then
        BTRFS_LAYOUT="A"
        log_info "Btrfs layout A: / is a subvolume (@)"
    elif echo "${subvol_info}" | grep -q 'path @root$'; then
        BTRFS_LAYOUT="A"
        log_info "Btrfs layout A: / is a subvolume (@root)"
    elif [[ -z "${subvol_info}" ]] || echo "${subvol_info}" | grep -q '^ID 256'; then
        BTRFS_LAYOUT="B"
        log_warn "Btrfs layout B: / is at top level (subvolid=5) - snapshots limited"
    else
        BTRFS_LAYOUT="A"
        log_info "Btrfs layout A: detected subvolume structure"
    fi

    log_debug "Btrfs subvolumes:\n${subvol_info}"
}

detect_gpu() {
    log_info "Detecting GPU..."

    local lspci_out
    lspci_out="$(lspci -nn 2>/dev/null | grep -E 'VGA|3D|Display' || true)"

    if echo "${lspci_out}" | grep -qi nvidia; then
        GPU_VENDOR="nvidia"
        log_info "GPU: NVIDIA detected"
    elif echo "${lspci_out}" | grep -qi amd; then
        GPU_VENDOR="amd"
        log_info "GPU: AMD detected"
    elif echo "${lspci_out}" | grep -qi intel; then
        GPU_VENDOR="intel"
        log_info "GPU: Intel detected"
    else
        GPU_VENDOR="unknown"
        log_warn "GPU: Could not detect vendor"
    fi

    log_debug "lspci output:\n${lspci_out}"
}

detect_vm() {
    if systemd-detect-virt -q >/dev/null 2>&1; then
        IS_VM="true"
        local virt_type
        virt_type="$(systemd-detect-virt)"
        log_info "Virtual machine detected: ${virt_type}"
    else
        IS_VM="false"
        log_info "Running on bare metal"
    fi
}

check_plasma_version() {
    log_info "Checking available Plasma version..."

    local policy
    policy="$(apt-cache policy plasma-desktop 2>/dev/null || true)"

    if echo "${policy}" | grep -q "Candidate:"; then
        PLASMA_VERSION="$(echo "${policy}" | grep "Candidate:" | awk '{print $2}')"
        log_info "Available plasma-desktop version: ${PLASMA_VERSION}"
    else
        log_warn "Could not determine plasma-desktop version from apt-cache"
        PLASMA_VERSION="unknown"
    fi
}

check_pardus_tools() {
    log_info "Checking for Pardus-specific tools that may conflict..."

    local tools=("pardus-guncelleme" "pardus-power-manager" "pardus-ayarlar")
    for tool in "${tools[@]}"; do
        if is_package_installed "${tool}"; then
            log_warn "Pardus tool installed: ${tool} - may need manual review after Plasma switch"
        fi
    done
}

confirm_proceed() {
    if [[ "${ASSUME_YES}" == "true" ]]; then
        return 0
    fi

    cat <<EOF

Preflight checks complete. Summary:
  OS: Pardus ${VERSION_ID} (${PRETTY_NAME})
  Root FS: ${ROOT_FS_TYPE} (${BTRFS_LAYOUT:-N/A})
  GPU: ${GPU_VENDOR}
  VM: ${IS_VM}
  Plasma available: ${PLASMA_VERSION}
  Profile: ${PROFILE}
  Gaming: ${ENABLE_GAMING}
  NVIDIA: ${ENABLE_NVIDIA}
  Dry-run: ${DRY_RUN}

EOF

    if [[ "${NO_SNAPSHOT}" == "false" && "${ROOT_FS_TYPE}" != "btrfs" ]]; then
        log_warn "No Btrfs detected - snapshots not available. /etc backup will be used instead."
        if ! confirm "Continue without Btrfs snapshots?"; then
            die "Aborted by user"
        fi
    fi

    if ! confirm "Proceed with installation?"; then
        die "Aborted by user"
    fi
}
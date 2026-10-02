#!/usr/bin/env bash
# Sopardus install.sh - Convert Pardus 25.2 GNOME to Sopardus (Plasma 6 Wayland)
# License: GPL-3.0-or-later

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    parse_args "$@"
    setup_logging
    log_info "Sopardus install.sh v0.3 starting"
    log_info "Log file: ${LOG_FILE}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY-RUN MODE: No changes will be made"
    fi

    run_phase "preflight" "${SCRIPT_DIR}/lib/00-preflight.sh"
    run_phase "snapshot" "${SCRIPT_DIR}/lib/10-snapshot.sh"
    run_phase "packages" "${SCRIPT_DIR}/lib/20-packages.sh"
    run_phase "session" "${SCRIPT_DIR}/lib/30-session.sh"
    run_phase "tuning" "${SCRIPT_DIR}/lib/40-tuning.sh"
    run_phase "theme" "${SCRIPT_DIR}/lib/50-theme.sh"
    run_phase "optional" "${SCRIPT_DIR}/lib/60-optional.sh"
    run_phase "finalize" "${SCRIPT_DIR}/lib/90-finalize.sh"

    log_info "Sopardus installation complete"
    print_summary
}

main "$@"
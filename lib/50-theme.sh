#!/usr/bin/env bash
# Phase 50: Theme and defaults (Ember theme, wallpapers, xdg/skel)
# License: GPL-3.0-or-later

phase_theme() {
    log_info "Applying Sopardus Ember theme and defaults..."

    if [[ "${DO_REVERT}" == "true" ]]; then
        revert_theme
        return 0
    fi

    install_ember_theme
    install_wallpapers
    configure_plasma_defaults
    configure_skel
    configure_gtk_theme
}

install_ember_theme() {
    log_info "Installing Ember color scheme..."

    local theme_dir="/usr/share/color-schemes"
    mkdir -p "${theme_dir}"

    cat > "${theme_dir}/SopardusEmberDark.colors" <<'EOF'
[ColorEffects:Disabled]
ColorAmount=0.35
ColorEffect=1
ContrastAmount=0.25
ContrastEffect=1
IntensityAmount=-0.2
IntensityEffect=1

[ColorEffects:Inactive]
ChangeSelectionColor=true
ColorAmount=0
ColorEffect=0
ContrastAmount=0
ContrastEffect=0
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=35,38,41
BackgroundNormal=28,30,33
DecorationFocus=255,144,44
DecorationHover=255,170,85
ForegroundActive=255,144,44
ForegroundInactive=115,115,115
ForegroundLink=255,144,44
ForegroundNegative=235,91,72
ForegroundNeutral=255,189,46
ForegroundNormal=205,205,205
ForegroundPositive=108,187,108
ForegroundVisited=187,134,252

[Colors:Complementary]
BackgroundAlternate=35,38,41
BackgroundNormal=28,30,33
DecorationFocus=255,144,44
DecorationHover=255,170,85
ForegroundActive=255,144,44
ForegroundInactive=115,115,115
ForegroundLink=255,144,44
ForegroundNegative=235,91,72
ForegroundNeutral=255,189,46
ForegroundNormal=205,205,205
ForegroundPositive=108,187,108
ForegroundVisited=187,134,252

[Colors:Selection]
BackgroundAlternate=255,144,44
BackgroundNormal=255,144,44
DecorationFocus=255,144,44
DecorationHover=255,170,85
ForegroundActive=28,30,33
ForegroundInactive=115,115,115
ForegroundLink=28,30,33
ForegroundNegative=235,91,72
ForegroundNeutral=255,189,46
ForegroundNormal=28,30,33
ForegroundPositive=108,187,108
ForegroundVisited=187,134,252

[Colors:Tooltip]
BackgroundAlternate=35,38,41
BackgroundNormal=28,30,33
DecorationFocus=255,144,44
DecorationHover=255,170,85
ForegroundActive=255,144,44
ForegroundInactive=115,115,115
ForegroundLink=255,144,44
ForegroundNegative=235,91,72
ForegroundNeutral=255,189,46
ForegroundNormal=205,205,205
ForegroundPositive=108,187,108
ForegroundVisited=187,134,252

[Colors:View]
BackgroundAlternate=35,38,41
BackgroundNormal=28,30,33
DecorationFocus=255,144,44
DecorationHover=255,170,85
ForegroundActive=255,144,44
ForegroundInactive=115,115,115
ForegroundLink=255,144,44
ForegroundNegative=235,91,72
ForegroundNeutral=255,189,46
ForegroundNormal=205,205,205
ForegroundPositive=108,187,108
ForegroundVisited=187,134,252

[Colors:Window]
BackgroundAlternate=35,38,41
BackgroundNormal=28,30,33
DecorationFocus=255,144,44
DecorationHover=255,170,85
ForegroundActive=255,144,44
ForegroundInactive=115,115,115
ForegroundLink=255,144,44
ForegroundNegative=235,91,72
ForegroundNeutral=255,189,46
ForegroundNormal=205,205,205
ForegroundPositive=108,187,108
ForegroundVisited=187,134,252

[General]
Name=Sopardus Ember Dark
shadeSortColumn=true
EOF
}

install_wallpapers() {
    log_info "Installing wallpapers..."

    local wallpaper_dir="/usr/share/wallpapers/Sopardus"
    mkdir -p "${wallpaper_dir}/contents/images"

    for res in 1920x1080 2560x1440 3840x2160; do
        mkdir -p "${wallpaper_dir}/contents/images/${res}"
    done

    cat > "${wallpaper_dir}/metadata.desktop" <<'EOF'
[Desktop Entry]
Name=Sopardus Ember
Type=Wallpaper
X-KDE-PluginInfo-Name=SopardusEmber
X-KDE-PluginInfo-License=CC-BY-SA-4.0
EOF

    create_placeholder_wallpapers "${wallpaper_dir}"
}

create_placeholder_wallpapers() {
    local wallpaper_dir="$1"
    local colors=("1c1e21" "232629" "2d3035")
    local accent="ff902c"

    for res in 1920x1080 2560x1440 3840x2160; do
        local w="${res%x*}"
        local h="${res#*x}"

        cat > "${wallpaper_dir}/contents/images/${res}/wallpaper.png" <<EOF
#!/usr/bin/env bash
# Placeholder - replace with actual PNG
# Sopardus Ember wallpaper ${res}
# Colors: #1c1e21 (deep), #${accent} (amber accent)
EOF
    done

    log_warn "Wallpaper placeholders created - replace with actual images in assets/wallpapers/"
}

configure_plasma_defaults() {
    log_info "Configuring Plasma defaults..."

    local kdeglobals="/etc/xdg/kdeglobals"
    mkdir -p "$(dirname "${kdeglobals}")"
    backup_file "${kdeglobals}"

    cat > "${kdeglobals}" <<'EOF'
[General]
ColorScheme=SopardusEmberDark
Font=Noto Sans,10,-1,5,50,0,0,0,0,0
fixed=Noto Sans Mono,10,-1,5,50,0,0,0,0,0
menuFont=Noto Sans,10,-1,5,50,0,0,0,0,0
smallestReadableFont=Noto Sans,8,-1,5,50,0,0,0,0,0
taskbarFont=Noto Sans,10,-1,5,50,0,0,0,0,0
toolBarFont=Noto Sans,10,-1,5,50,0,0,0,0,0

[KDE]
LookAndFeelPackage=org.sopardus.desktop
SingleClick=false

[Icons]
Theme=SopardusEmber

[KWin]
BorderlessMaximizedWindows=true
ElectricBorderMaximize=true
ElectricBorderTiling=true
RollOverDesktops=false

[Windows]
TitlebarButtons=ximak
EOF
}

configure_skel() {
    log_info "Configuring /etc/skel defaults..."

    local skel_dir="/etc/skel"
    mkdir -p "${skel_dir}/.config"

    cat > "${skel_dir}/.config/kdeglobals" <<'EOF'
[General]
ColorScheme=SopardusEmberDark
Font=Noto Sans,10,-1,5,50,0,0,0,0,0
fixed=Noto Sans Mono,10,-1,5,50,0,0,0,0,0
menuFont=Noto Sans,10,-1,5,50,0,0,0,0,0
smallestReadableFont=Noto Sans,8,-1,5,50,0,0,0,0,0
taskbarFont=Noto Sans,10,-1,5,50,0,0,0,0,0
toolBarFont=Noto Sans,10,-1,5,50,0,0,0,0,0

[KDE]
LookAndFeelPackage=org.sopardus.desktop
SingleClick=false
EOF

    mkdir -p "${skel_dir}/.config/kwinrc"
    cat > "${skel_dir}/.config/kwinrc" <<'EOF'
[Windows]
TitlebarButtons=ximak
BorderlessMaximizedWindows=true
ElectricBorderMaximize=true
ElectricBorderTiling=true

[Compositing]
Backend=OpenGL
OpenGLIsUnsafe=false
EOF
}

configure_gtk_theme() {
    log_info "Configuring GTK theme (Breeze + Ember)..."

    local gtk3_dir="/etc/gtk-3.0"
    mkdir -p "${gtk3_dir}"

    cat > "${gtk3_dir}/settings.ini" <<'EOF'
[Settings]
gtk-theme-name = Breeze-Dark
gtk-icon-theme-name = SorpadusEmber
gtk-font-name = Noto Sans 10
gtk-cursor-theme-name = breeze_cursors
gtk-cursor-theme-size = 24
gtk-toolbar-style = GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size = GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images = 1
gtk-menu-images = 1
gtk-enable-event-sounds = 1
gtk-enable-input-feedback-sounds = 1
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintfull
gtk-xft-rgba = rgb
EOF

    local gtk4_dir="/etc/gtk-4.0"
    mkdir -p "${gtk4_dir}"
    cp "${gtk3_dir}/settings.ini" "${gtk4_dir}/settings.ini"
}

revert_theme() {
    log_info "Reverting theme changes..."

    restore_file "/etc/xdg/kdeglobals"
    restore_file "/etc/gtk-3.0/settings.ini"
    restore_file "/etc/gtk-4.0/settings.ini"

    log_info "Theme reverted (user configs in ~/.config preserved)"
}
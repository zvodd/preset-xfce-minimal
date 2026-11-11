#!/usr/bin/env bash
# preset-xfce-minimal - one-file, distro-agnostic minimal XFCE4 preset.
#
#   One panel (Start menu | window buttons | ...spacer... | tray | clock)
#   One workspace, no pager, no desktop icons, solid black desktop,
#   compositor off (fast over VNC/RDP, clean screenshots for agents),
#   screen locker off, dark GTK theme if one is installed.
#
# Usage:  preset-xfce-minimal.sh [--install] [--bottom] [--bg RRGGBB] [--no-restart]
#                     [--no-backup] [--revert] [-h]
#   curl -fsSL <raw-url>/preset-xfce-minimal.sh | bash -s -- --install
set -euo pipefail

INSTALL=0; BOTTOM=0; BG="000000"; RESTART=1; BACKUP=1; REVERT=0

die() { echo "preset-xfce-minimal: $*" >&2; exit 1; }
log() { echo "preset-xfce-minimal: $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --install)    INSTALL=1 ;;
    --bottom)     BOTTOM=1 ;;
    --bg)         shift; BG="${1#\#}" ;;
    --no-restart) RESTART=0 ;;
    --no-backup)  BACKUP=0 ;;
    --revert)     REVERT=1 ;;
    -h|--help)    sed -n '2,13p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown option: $1" ;;
  esac
  shift
done
[[ "$BG" =~ ^[0-9a-fA-F]{6}$ ]] || die "--bg wants 6 hex digits, e.g. 000000"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
XML="$CFG/xfce4/xfconf/xfce-perchannel-xml"
PANELDIR="$CFG/xfce4/panel"
BKDIR="$CFG/preset-xfce-minimal-backups"

# ---------------------------------------------------------------- packages --
install_pkgs() {
  local SUDO=""
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "need root or sudo for --install"
    SUDO="sudo"
  fi
  if   command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      xfce4-panel xfdesktop4 xfwm4 xfce4-session xfce4-settings xfconf \
      xfce4-whiskermenu-plugin xfce4-terminal dbus-x11 x11-xserver-utils \
      adwaita-icon-theme fonts-dejavu-core
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y xfce4-panel xfdesktop xfwm4 xfce4-session xfce4-settings \
      xfconf xfce4-whiskermenu-plugin xfce4-terminal dbus-x11 xrandr
  elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -S --needed --noconfirm xfce4-panel xfdesktop xfwm4 xfce4-session \
      xfce4-settings xfconf xfce4-whiskermenu-plugin xfce4-terminal xorg-xrandr
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add xfce4-panel xfdesktop xfwm4 xfce4-session xfce4-settings xfconf \
      xfce4-whiskermenu-plugin xfce4-terminal xrandr dbus-x11
  else
    die "no supported package manager (apt/dnf/pacman/apk); install XFCE yourself and re-run without --install"
  fi
}

# ------------------------------------------------------------------ helpers --
pick_theme() {
  local t d
  for t in Adwaita-dark Greybird-dark Arc-Dark Mint-Y-Dark Yaru-dark Materia-dark; do
    for d in /usr/share/themes "$HOME/.themes" "${XDG_DATA_HOME:-$HOME/.local/share}/themes"; do
      [ -d "$d/$t" ] && { echo "$t"; return; }
    done
  done
  echo ""
}

monitors() {
  # common names first (xfdesktop keys backdrops by output name), then live ones
  local m
  for m in 0 VNC-0 XVNC-0 rdp0 Virtual-1 Virtual1 DP-1 HDMI-1 eDP-1 default; do echo "$m"; done
  if [ -n "${DISPLAY:-}" ] && command -v xrandr >/dev/null 2>&1; then
    xrandr --listmonitors 2>/dev/null | awk 'NR>1 {print $NF}' || true
  fi
}

session_live() { [ -n "${DISPLAY:-}" ] && pgrep -x xfce4-panel >/dev/null 2>&1; }

# ------------------------------------------------------------ config writers --
write_config() {
  mkdir -p "$XML" "$PANELDIR" "$CFG/autostart"
  local theme panelpos r g b
  theme="$(pick_theme)"
  [ "$BOTTOM" -eq 1 ] && panelpos="p=10;x=0;y=0" || panelpos="p=6;x=0;y=0"
  r=$(awk -v v=$((16#${BG:0:2})) 'BEGIN{printf "%.4f", v/255}')
  g=$(awk -v v=$((16#${BG:2:2})) 'BEGIN{printf "%.4f", v/255}')
  b=$(awk -v v=$((16#${BG:4:2})) 'BEGIN{printf "%.4f", v/255}')

  # ---- panel: ONE panel. whisker | tasklist | spacer | tray | clock
  cat > "$XML/xfce4-panel.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="$panelpos"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="length" type="uint" value="100"/>
      <property name="size" type="uint" value="32"/>
      <property name="nrows" type="uint" value="1"/>
      <property name="mode" type="uint" value="0"/>
      <property name="icon-size" type="uint" value="0"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="tasklist">
      <property name="grouping" type="uint" value="0"/>
      <property name="show-labels" type="bool" value="true"/>
      <property name="flat-buttons" type="bool" value="true"/>
      <property name="show-handle" type="bool" value="false"/>
      <property name="include-all-workspaces" type="bool" value="true"/>
    </property>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray">
      <property name="show-frame" type="bool" value="false"/>
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-5" type="string" value="clock">
      <property name="mode" type="uint" value="2"/>
      <property name="digital-layout" type="uint" value="4"/>
      <property name="digital-format" type="string" value="%a %d %b  %H:%M"/>
    </property>
  </property>
</channel>
EOF

  cat > "$PANELDIR/whiskermenu-1.rc" <<'EOF'
button-title=Start
show-button-title=true
show-button-icon=true
launcher-show-description=false
launcher-show-tooltip=false
show-command-settings=false
show-command-lockscreen=false
show-command-switchuser=false
EOF

  # ---- desktop: solid colour, no icons, no right-click menus
  {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="single-workspace-mode" type="bool" value="true"/>
    <property name="single-workspace-number" type="uint" value="0"/>
    <property name="screen0" type="empty">
EOF
    monitors | sort -u | while read -r m; do
      [ -n "$m" ] || continue
      cat <<EOF
      <property name="monitor$m" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="0"/>
          <property name="rgba1" type="array">
            <value type="double" value="$r"/>
            <value type="double" value="$g"/>
            <value type="double" value="$b"/>
            <value type="double" value="1"/>
          </property>
        </property>
      </property>
EOF
    done
    cat <<'EOF'
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="0"/>
  </property>
  <property name="desktop-menu" type="empty">
    <property name="show" type="bool" value="false"/>
  </property>
  <property name="windowlist-menu" type="empty">
    <property name="show" type="bool" value="false"/>
  </property>
</channel>
EOF
  } > "$XML/xfce4-desktop.xml"

  # ---- window manager: 1 workspace, no compositor, no shadows
  cat > "$XML/xfwm4.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="workspace_count" type="int" value="1"/>
    <property name="wrap_workspaces" type="bool" value="false"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
    <property name="show_frame_shadow" type="bool" value="false"/>
    <property name="show_popup_shadow" type="bool" value="false"/>
    <property name="title_font" type="string" value="Sans Bold 10"/>
  </property>
</channel>
EOF

  # ---- look: dark GTK theme if present, readable font, no sounds
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<channel name="xsettings" version="1.0">'
    echo '  <property name="Net" type="empty">'
    [ -n "$theme" ] && echo "    <property name=\"ThemeName\" type=\"string\" value=\"$theme\"/>"
    echo '    <property name="EnableEventSounds" type="bool" value="false"/>'
    echo '    <property name="EnableInputFeedbackSounds" type="bool" value="false"/>'
    echo '  </property>'
    echo '  <property name="Gtk" type="empty">'
    echo '    <property name="FontName" type="string" value="Sans 10"/>'
    echo '  </property>'
    echo '  <property name="Xft" type="empty">'
    echo '    <property name="Antialias" type="int" value="1"/>'
    echo '    <property name="Hinting" type="int" value="1"/>'
    echo '    <property name="HintStyle" type="string" value="hintslight"/>'
    echo '    <property name="RGBA" type="string" value="rgb"/>'
    echo '  </property>'
    echo '</channel>'
  } > "$XML/xsettings.xml"

  # ---- session: never restore saved sessions (reproducible containers)
  cat > "$XML/xfce4-session.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="SaveOnExit" type="bool" value="false"/>
  </property>
</channel>
EOF

  # ---- no screen locker kicking agents/VNC users out
  local a
  for a in xfce4-screensaver light-locker xscreensaver; do
    printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "$a" \
      > "$CFG/autostart/$a.desktop"
  done
}

backup() {
  [ -d "$CFG/xfce4" ] || return 0
  mkdir -p "$BKDIR"
  local f="$BKDIR/xfce4-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
  tar czf "$f" -C "$CFG" xfce4 && log "backed up old config -> $f"
}

revert() {
  local last
  last="$(ls -1t "$BKDIR"/xfce4-*.tar.gz 2>/dev/null | head -n1 || true)"
  [ -n "$last" ] || die "no backup found in $BKDIR"
  rm -rf "$CFG/xfce4"
  tar xzf "$last" -C "$CFG"
  log "restored $last"
}

stop_bits() {
  xfce4-panel --quit >/dev/null 2>&1 || true
  pkill -x xfdesktop >/dev/null 2>&1 || true
  pkill -x xfconfd   >/dev/null 2>&1 || true   # else it overwrites our XML on exit
  sleep 1
}
start_bits() {
  local s
  for s in "xfsettingsd --replace" "xfwm4 --replace" "xfce4-panel" "xfdesktop"; do
    # shellcheck disable=SC2086
    command -v "${s%% *}" >/dev/null 2>&1 && setsid nohup $s >/dev/null 2>&1 &
  done
  sleep 1
}

# --------------------------------------------------------------------- main --
if [ "$REVERT" -eq 1 ]; then
  session_live && stop_bits
  revert
  session_live || true
  log "done (log out/in or restart the panel to see it)"
  exit 0
fi

[ "$INSTALL" -eq 1 ] && install_pkgs
[ "$BACKUP"  -eq 1 ] && backup

LIVE=0
if [ "$RESTART" -eq 1 ] && session_live; then LIVE=1; stop_bits; fi
write_config
[ "$LIVE" -eq 1 ] && start_bits

log "applied. panel=$([ "$BOTTOM" -eq 1 ] && echo bottom || echo top) bg=#$BG theme=$(pick_theme)"
[ "$LIVE" -eq 1 ] || log "no running XFCE session detected: changes take effect at next login"

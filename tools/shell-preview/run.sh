#!/usr/bin/bash
# Screenshots the desktop shell without a GPU or Hyprland: runs inside the built image (as root),
# adds a headless sway and a stand-in for Hyprland's IPC (fake_hypr.py), starts the shell as a
# normal account, opens each requested panel and saves a screenshot of it to /out.
#
#   SHOTS="dashboard:drawers toggle dashboard;lock:lock lock"   name:IPC call, ";"-separated
#   (a call starting with ! is a shell command instead, e.g. "toast:!notify-send Hello")
#   RHI=vulkan (default, lavapipe) or software; software loses the panels' backgrounds.
#   FAKE_WINDOWS=1 pretends a few windows are open (one minimized), for the taskbar.
#   FAKE_ORCHESTRATOR=signed-out|signing-in|failed|signed-in puts a stand-in for the Orchestrator's
#   agent (fake-sam-orchestrator) in place of the real one (which, left alone, the session bus here
#   starts, and Settings shows as signed out), for Settings' Your account and Your
#   devices pages and the Devices card. Settings opens with a "!" call (a second call would open a
#   second window, not close the first), so close the one before:
#     SHOTS='account:!qs -c caelestia ipc call nexus openPage account;devices:!swaymsg kill && qs -c caelestia ipc call nexus openPage yourdevices'
#
# `just shell-preview` runs it; see the Justfile.
set -u
dnf -q -y install sway grim mesa-vulkan-drivers vulkan-loader dbus-daemon >/dev/null 2>&1 ||
    { echo "couldn't install sway and friends"; exit 1; }
setcap -r /usr/bin/sway 2>/dev/null || true # its file capability fails in an unprivileged container
id sam >/dev/null 2>&1 || useradd -m -c "Sam" sam
if [ -n "${FAKE_ORCHESTRATOR:-}" ]; then
    dnf -q -y install python3-gobject-base >/dev/null 2>&1
    # Over the real one: this container is thrown away, and /usr/local isn't there in it.
    install -m755 /preview/fake-sam-orchestrator /usr/bin/sam-orchestrator
fi
cat > /tmp/inner.sh <<'EOF'
set -u
export XDG_RUNTIME_DIR=/tmp/xdg-$(id -u); mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 LANG=C.UTF-8
export QT_FORCE_STDERR_LOGGING=1 QSG_RHI_BACKEND=${RHI:-vulkan}
/usr/libexec/superawesomemagical/user-setup
caelestia scheme set --name superawesomemagical --flavour default --mode dark >/dev/null 2>&1
caelestia wallpaper --file /usr/share/backgrounds/superawesomemagical/aurora.jpg >/dev/null 2>&1
printf 'output HEADLESS-1 resolution 1920x1080\n' > /tmp/sway.conf
sway -c /tmp/sway.conf > /out/sway.log 2>&1 &
for i in $(seq 1 50); do ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1 && break; sleep 0.2; done
export WAYLAND_DISPLAY=$(basename "$(ls "$XDG_RUNTIME_DIR"/wayland-[0-9] | head -1)")
export SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock | head -1) # for swaymsg in a "!" shot
export HYPRLAND_INSTANCE_SIGNATURE=fakehypr
python3 /preview/fake_hypr.py > /out/fake_hypr.log 2>&1 &
# The stand-in agent is "running" when someone's signed in, as start-shell would have seen to.
[ "${FAKE_ORCHESTRATOR:-}" = signed-in ] && sam-orchestrator daemon > /out/fake_orchestrator.log 2>&1 &
sleep 0.5
qs -c caelestia > /out/shell.log 2>&1 &
sleep 12
grim /out/desktop.png
IFS=';' read -ra targets <<< "${SHOTS:-}"
for target in "${targets[@]}"; do
    [ -n "$target" ] || continue
    name=${target%%:*} call=${target#*:}
    if [ "${call:0:1}" = "!" ]; then # a shell command, e.g. !notify-send hello
        eval "${call:1}" >> /out/ipc.log 2>&1 &
        sleep 3
        grim "/out/$name.png"
        continue
    fi
    eval "qs -c caelestia ipc call $call" >> /out/ipc.log 2>&1
    sleep 3
    grim "/out/$name.png"
    # Close it again (the lock screen can't be, so put it last).
    eval "qs -c caelestia ipc call $call" >> /out/ipc.log 2>&1
    sleep 1
done
EOF
chmod 755 /tmp/inner.sh
chown sam /out
export SHOTS=${SHOTS:-} RHI=${RHI:-vulkan} FAKE_WINDOWS=${FAKE_WINDOWS:-} FAKE_ORCHESTRATOR=${FAKE_ORCHESTRATOR:-}
su - sam -w SHOTS,RHI,FAKE_WINDOWS,FAKE_ORCHESTRATOR -c "dbus-run-session -- bash /tmp/inner.sh"
ls /out

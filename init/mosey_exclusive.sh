#!/system/bin/sh
set -u
PATH=/system/bin

readonly TAG=mosey_exclusive
readonly CON_MODE=/sys/module/wlan/parameters/con_mode
readonly TIMEOUT=15

log_i() { echo "$TAG: $*" > /dev/kmsg; }
fail()  { log_i "FAIL: $*"; exit 1; }

reload_wlan() {
    stop cnss-daemon
    sleep 2
    start cnss-daemon
}

# wlan0 ARPHRD type: 1 = ARPHRD_ETHER (managed STA); any other value = monitor.
wait_for_wlan_type() {
    local want=$1 i=0 t
    while [ "$i" -lt "$TIMEOUT" ]; do
        t=$(cat /sys/class/net/wlan0/type 2>/dev/null)
        case "$want" in
            managed) [ "$t" = 1 ] && return 0 ;;
            monitor) [ -n "$t" ] && [ "$t" != 1 ] && return 0 ;;
        esac
        sleep 1
        i=$((i + 1))
    done
    return 1
}

restore_sta() {
    setprop sys.mosey.exclusive 0
    echo 0 > "$CON_MODE" 2>/dev/null
    reload_wlan
    cmd wifi set-wifi-enabled enabled
}

cmd_on() {
    # Tell the Wi-Fi framework (HalDeviceManager) to stop allocating STA/NAN on wlan0.
    setprop sys.mosey.exclusive 1

    # con_mode is a module param reset on reboot, so its live value is authoritative.
    if [ "$(cat "$CON_MODE" 2>/dev/null)" = "4" ]; then
        start mosey_server
        log_i "OK already exclusive (con_mode=4); ensured mosey_server"
        return 0
    fi

    trap 'log_i "ROLLBACK from failed on()"; restore_sta' EXIT INT TERM

    cmd wifi set-wifi-enabled disabled
    sleep 2
    stop mosey_server 2>/dev/null

    echo 4 > "$CON_MODE" || fail "cannot write con_mode=4"
    reload_wlan
    wait_for_wlan_type monitor || fail "timeout waiting for wlan0 monitor"
    [ "$(cat "$CON_MODE" 2>/dev/null)" = "4" ] || fail "con_mode not applied"

    start mosey_server

    trap - EXIT INT TERM
    log_i "OK exclusive monitor + mosey_server (con_mode=4)"
}

cmd_off() {
    setprop sys.mosey.exclusive 0
    stop mosey_server 2>/dev/null

    # Also neutralizes vendor mosey.rc "on boot start mosey_server" when spoof is off.
    if [ "$(cat "$CON_MODE" 2>/dev/null)" = "4" ]; then
        echo 0 > "$CON_MODE" || fail "cannot restore con_mode=0"
        reload_wlan
        wait_for_wlan_type managed || log_i "WARN wlan0 not managed within ${TIMEOUT}s"
    fi
    cmd wifi set-wifi-enabled enabled
    log_i "OK STA restored (con_mode=$(cat "$CON_MODE" 2>/dev/null)), mosey_server stopped"
}

case "${1:-}" in
    on)  cmd_on  ;;
    off) cmd_off ;;
    *)   fail "usage: $0 on|off" ;;
esac

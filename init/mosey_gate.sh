#!/system/bin/sh
PATH=/system/bin

readonly TAG=mosey_gate
readonly POLL=15
log_i() { echo "$TAG: $*" > /dev/kmsg; }

# Match PixelPropsUtils' gate: the Mosey monitor activates only when the per-app
# target is present AND the global pi_pp_spoof switch is on (Settings default 1).
# pi_pp_targets is a CSV the framework splits and matches by exact token.
#
# Apply once at boot, then poll those secure settings and re-apply only on a real
# change, so toggling the spoof takes effect without a reboot. cmd settings needs root.
last=""
while true; do
    targets=$(cmd settings get secure pi_pp_targets)
    spoof=$(cmd settings get secure pi_pp_spoof)

    # An empty value (as opposed to the literal "null") means the read failed, e.g. the
    # settings provider is briefly unavailable. Keep the last state instead of toggling.
    if [ -n "$spoof" ] && [ -n "$targets" ]; then
        case "$spoof" in
            1|null) spoof_on=1 ;;
            *)      spoof_on=0 ;;
        esac
        case ",$targets," in
            *,com.google.android.mosey,*) mosey=1 ;;
            *)                            mosey=0 ;;
        esac
        if [ "$mosey" = 1 ] && [ "$spoof_on" = 1 ]; then cur=on; else cur=off; fi

        if [ "$cur" != "$last" ]; then
            last=$cur
            if [ "$cur" = on ]; then
                log_i "Mosey spoof active -> exclusive monitor"
                setprop ctl.start mosey_exclusive_on
            else
                log_i "Mosey spoof inactive (mosey=$mosey spoof_on=$spoof_on) -> restore STA"
                setprop ctl.start mosey_exclusive_off
            fi
        fi
    fi

    sleep "$POLL"
done

#!/system/bin/sh
# Attach Umbra to all post-process streams at boot.
# The vendor partition is read-only, so the patched config is assembled in
# /data/vendor and init bind-mounts it over the stock one before audioserver
# starts (audio_effects.xml is read once, at audioserver startup). The copy
# keeps its umbra_data_file label; audioserver is granted read in sepolicy.

SRC=/vendor/etc/audio_effects.xml
OUT=/data/vendor/umbra/audio_effects.xml

STREAMS="music patch rerouting voice_call ring alarm notification assistant"

# libumbra.so mirrors the app's multichannel switch into this file from the
# audio HAL: "1 <uuids>" hands the spatializer to Umbra in place of the listed
# effects, anything else keeps the stock one. It is written after this script
# has run, so a change takes effect on the next boot.
SPATIAL_FLAG=/data/vendor/umbra/spatial
SPATIAL_UUID=a987e55e-ec24-48a7-8079-9a16922b4593

cp -f "$SRC" "$OUT.tmp" || exit 1

for _s in $STREAMS; do
    if grep -q "<stream type=\"$_s\">" "$OUT.tmp"; then
        sed -i "/<stream type=\"$_s\">/a\\            <apply effect=\"umbra\"/>" "$OUT.tmp"
    else
        sed -i "/<postprocess>/a\\        <stream type=\"$_s\">\n            <apply effect=\"umbra\"/>\n        </stream>" "$OUT.tmp"
    fi
done

_mode=
_uuids=
[ -r "$SPATIAL_FLAG" ] && read -r _mode _uuids < "$SPATIAL_FLAG"
if [ "$_mode" = 1 ]; then
    for _u in $_uuids; do
        case "$_u" in *[!0-9a-f-]*) continue ;; esac
        sed -i "/<effect [^>]*uuid=\"$_u\"[^>]*\/>/d" "$OUT.tmp"
    done
    sed -i "/<effects>/a\\        <effect name=\"umbra_spatial\" library=\"umbra\" uuid=\"$SPATIAL_UUID\"/>" "$OUT.tmp"
fi

chmod 0644 "$OUT.tmp"
mv -f "$OUT.tmp" "$OUT"

#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Launch the CARLA 0.9.16 server (Linux).
#
#   ./launch_carla.sh                 # windowed (default), port 2000
#   ./launch_carla.sh --offscreen     # headless GPU render, no window
#   ./launch_carla.sh --lowgfx        # headless + low quality (lighter GPU)
#   ./launch_carla.sh --port 2010     # another instance; uses ports 2010-2012
#
# Remaining arguments are passed to CarlaUE4.sh, e.g.:
#   ./launch_carla.sh --window -quality-level=Epic -ResX=1920 -ResY=1080
#   ./launch_carla.sh --offscreen --ros2
#
# Headless modes still render on the GPU, so camera sensors work.
# ---------------------------------------------------------------------------
set -euo pipefail

CARLA_ROOT="${CARLA_ROOT:-${CARLA_SIM_DIR:-$HOME/carla-sim}/CARLA_0.9.16}"
MODE="window"
PORT="2000"
while [ $# -gt 0 ]; do
    case "$1" in
        --window)    MODE="window";    shift ;;
        --offscreen) MODE="offscreen"; shift ;;
        --lowgfx)    MODE="lowgfx";    shift ;;
        --port)      PORT="${2:-}";    shift 2 ;;
        *)           break ;;
    esac
done

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65533 ]; then
    echo "[launch] error: --port must be a number from 1024 to 65533" >&2
    exit 2
fi
if [ ! -x "$CARLA_ROOT/CarlaUE4.sh" ]; then
    echo "[launch] error: CarlaUE4.sh not found at $CARLA_ROOT. Set CARLA_ROOT or check the install path." >&2
    exit 1
fi

# CARLA uses the first -carla-rpc-port it sees, so add the default only when
# the caller did not pass one.
ARGS=(-nosound)
case " $* " in
    *" -carla-rpc-port="*) ;;
    *) ARGS=(-carla-rpc-port="$PORT" "${ARGS[@]}") ;;
esac
case "$MODE" in
    offscreen) ARGS+=(-RenderOffScreen) ;;
    lowgfx)    ARGS+=(-RenderOffScreen -quality-level=Low) ;;
    window)    ;;
esac

echo "[launch] CARLA_ROOT=$CARLA_ROOT"
echo "[launch] mode=$MODE  args: ${ARGS[*]} $*"
exec "$CARLA_ROOT/CarlaUE4.sh" "${ARGS[@]}" "$@"

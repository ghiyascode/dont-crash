#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# CARLA 0.9.16 environment setup for Linux (bash or zsh).
# Source this file so the variables persist in the current shell:
#
#     source ~/carla-sim/setup_env.sh
#
# Activates the `carla` conda env and sets CARLA_ROOT, SCENARIO_RUNNER_ROOT,
# and PYTHONPATH (CARLA `agents` package + ScenarioRunner). Safe to run more
# than once.
# Defaults: ~/carla-sim and conda env `carla`
# (override with CARLA_SIM_DIR and CARLA_CONDA_ENV)
# ---------------------------------------------------------------------------

CARLA_SIM_DIR="${CARLA_SIM_DIR:-$HOME/carla-sim}"
CARLA_CONDA_ENV="${CARLA_CONDA_ENV:-carla}"
export CARLA_ROOT="$CARLA_SIM_DIR/CARLA_0.9.16"
export SCENARIO_RUNNER_ROOT="$CARLA_SIM_DIR/scenario_runner"

[ -x "$CARLA_ROOT/CarlaUE4.sh" ] || echo "[carla-env] warning: CarlaUE4.sh not found in $CARLA_ROOT" >&2

# --- conda ---
for _conda_sh in "$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3"; do
    if [ -f "$_conda_sh/etc/profile.d/conda.sh" ]; then
        . "$_conda_sh/etc/profile.d/conda.sh"
        break
    fi
done
unset _conda_sh
if command -v conda >/dev/null 2>&1; then
    conda activate "$CARLA_CONDA_ENV"
else
    echo "[carla-env] warning: conda not found; install Miniforge (see carla/README.md)" >&2
fi

# --- Python path (prepend each entry once) ---
for _p in "$SCENARIO_RUNNER_ROOT" "$CARLA_ROOT/PythonAPI/carla"; do
    case ":${PYTHONPATH:-}:" in
        *":$_p:"*) ;;
        *) PYTHONPATH="$_p${PYTHONPATH:+:$PYTHONPATH}" ;;
    esac
done
unset _p
export PYTHONPATH

echo "[carla-env] conda env : ${CONDA_DEFAULT_ENV:-none}"
echo "[carla-env] CARLA_ROOT: $CARLA_ROOT (v$(cat "$CARLA_ROOT/VERSION" 2>/dev/null || echo '?'))"
echo "[carla-env] SR_ROOT   : $SCENARIO_RUNNER_ROOT"
echo "[carla-env] Start the simulator with: $CARLA_SIM_DIR/launch_carla.sh"

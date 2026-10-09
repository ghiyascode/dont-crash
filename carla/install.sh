#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-command installer for the CARLA 0.9.16 simulation environment (Linux).
#
#   ./install.sh                  full install into ~/carla-sim
#   ./install.sh --help           list options
#
# Installs CARLA 0.9.16 (+ additional maps), ScenarioRunner v0.9.16, a conda
# environment with the CARLA client and dependencies, PyTorch (CUDA build on
# NVIDIA, CPU build otherwise), the helper scripts, and optionally ROS 2
# Humble. Ends with a smoke test that renders one frame.
#
# Safe to re-run: completed steps are skipped and interrupted downloads resume.
# ---------------------------------------------------------------------------
set -eo pipefail

CARLA_VERSION="0.9.16"
SR_TAG="v0.9.16"
PYTHON_VERSION="3.11"
TORCH_VERSION="2.8.0"
TORCHVISION_VERSION="0.23.0"
CARLA_URL="https://downloads.carlasim.com/Linux/CARLA_${CARLA_VERSION}.tar.gz"
MAPS_URL="https://downloads.carlasim.com/Linux/AdditionalMaps_${CARLA_VERSION}.tar.gz"
SR_REPO="https://github.com/carla-simulator/scenario_runner.git"
MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
TORCH_INDEX="https://download.pytorch.org/whl"
NVIDIA_INDEX_PROBE="${CARLA_INSTALL_NVIDIA_PROBE:-https://pypi.nvidia.com/}"

# Sizes in GiB (measured), used for the free-space check.
SIZE_CARLA_ARCHIVE=8;  SIZE_CARLA_EXTRACTED=19
SIZE_MAPS_ARCHIVE=14;  SIZE_MAPS_EXTRACTED=11
SIZE_PY_ENV=8;         SIZE_ROS_ENV=4

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$SCRIPT_DIR/setup"

INSTALL_DIR="$HOME/carla-sim"
ENV_NAME="carla"
ROS_ENV_NAME="ros_humble"
WITH_MAPS=1
TORCH_MODE="auto"
WITH_ROS2=0
RUN_SMOKETEST=1
REMOVE_ARCHIVES=0
REUSE_ENV=0
# Marker file placed in environments this installer creates. An existing env
# without it belongs to something else and is not modified unless --reuse-env.
ENV_MARKER=".carla-sim-installer"

usage() {
    cat <<EOF
Usage: ./install.sh [options]

Options:
  --dir PATH          Install location (default: ~/carla-sim)
  --env NAME          Conda environment name (default: carla)
  --no-maps           Skip the additional maps (saves ~25 GB)
  --torch MODE        PyTorch build: auto, cuda, cpu, or none (default: auto;
                      cuda on NVIDIA GPUs, cpu otherwise)
  --no-torch          Same as --torch none
  --with-ros2         Also install ROS 2 Humble in a separate conda env
  --ros-env NAME      ROS 2 environment name (default: ros_humble)
  --no-smoketest      Skip the final smoke test
  --remove-archives   Delete the downloaded archives after extraction
  --reuse-env         Allow installing into an existing conda environment that
                      this installer did not create (its packages will change)
  -h, --help          Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dir)             INSTALL_DIR="$2"; shift 2 ;;
        --env)             ENV_NAME="$2"; shift 2 ;;
        --no-maps)         WITH_MAPS=0; shift ;;
        --torch)           TORCH_MODE="$2"; shift 2 ;;
        --no-torch)        TORCH_MODE="none"; shift ;;
        --with-ros2)       WITH_ROS2=1; shift ;;
        --ros-env)         ROS_ENV_NAME="$2"; shift 2 ;;
        --no-smoketest)    RUN_SMOKETEST=0; shift ;;
        --remove-archives) REMOVE_ARCHIVES=1; shift ;;
        --reuse-env)       REUSE_ENV=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *)                 echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# --- output helpers --------------------------------------------------------

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }

# --- argument validation ---------------------------------------------------

case "$TORCH_MODE" in auto|cuda|cpu|none) ;; *) die "--torch must be auto, cuda, cpu, or none" ;; esac
for n in "$ENV_NAME" "$ROS_ENV_NAME"; do
    [[ "$n" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid environment name: '$n'"
done
case "$INSTALL_DIR" in *'"'*|*'$'*|*'`'*|*'\'*) die "install path may not contain \" \$ \` or \\" ;; esac
INSTALL_DIR="$(realpath -m "$INSTALL_DIR")"

CARLA_ROOT="$INSTALL_DIR/CARLA_$CARLA_VERSION"
SR_DIR="$INSTALL_DIR/scenario_runner"
DL_DIR="$INSTALL_DIR/downloads"
LOG_DIR="$INSTALL_DIR/logs"

mkdir -p "$DL_DIR" "$LOG_DIR"
LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "CARLA $CARLA_VERSION installer — $(date)"
echo "Install location: $INSTALL_DIR"
echo "Log file:         $LOG"

SERVER_PGID=""
stop_server() {
    [ -n "$SERVER_PGID" ] || return 0
    kill -TERM -- "-$SERVER_PGID" 2>/dev/null || true
    for _ in $(seq 1 20); do
        kill -0 -- "-$SERVER_PGID" 2>/dev/null || break
        sleep 1
    done
    kill -KILL -- "-$SERVER_PGID" 2>/dev/null || true
    SERVER_PGID=""
}
trap stop_server EXIT
trap 'stop_server; exit 130' INT TERM

# --- 1. preflight ----------------------------------------------------------

step "Checking system"

[ "$(uname -s)" = "Linux" ] || die "this installer is for Linux; on Windows use install.ps1"
[ "$(uname -m)" = "x86_64" ] || die "CARLA $CARLA_VERSION packages are x86_64 only"
for cmd in curl tar git setsid; do
    command -v "$cmd" >/dev/null || die "'$cmd' is required. Ubuntu: sudo apt install $cmd   Fedora: sudo dnf install $cmd"
done

LDCONFIG="$(command -v ldconfig || echo /sbin/ldconfig)"
# Capture output before grepping: with pipefail, `cmd | grep -q` can fail when
# grep exits early and cmd gets SIGPIPE.
if ! grep -q 'libvulkan\.so\.1' <<<"$("$LDCONFIG" -p 2>/dev/null)"; then
    die "the Vulkan loader (libvulkan.so.1) is missing. Ubuntu: sudo apt install libvulkan1   Fedora: sudo dnf install vulkan-loader"
fi
info "Vulkan loader: found"

GPU="unknown"
if command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then
    GPU="nvidia"
    info "GPU: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1) (NVIDIA driver OK)"
elif command -v lspci >/dev/null; then
    gpus="$(lspci | grep -Ei 'vga|3d|display' || true)"
    if grep -qi nvidia <<<"$gpus"; then
        GPU="nvidia"
        warn "NVIDIA GPU detected but nvidia-smi is not working. Install the NVIDIA driver; CARLA cannot render without it."
    elif grep -Eqi 'amd|ati|radeon' <<<"$gpus"; then
        GPU="amd"
        info "GPU: $(grep -Ei 'amd|ati|radeon' <<<"$gpus" | head -1 | cut -d: -f3- | sed 's/^ *//')"
    fi
fi
[ "$GPU" = "unknown" ] && warn "could not identify a dedicated GPU; CARLA requires an NVIDIA or AMD GPU with Vulkan support"

if [ "$TORCH_MODE" = "auto" ]; then
    if [ "$GPU" = "nvidia" ]; then TORCH_MODE="cuda"; else TORCH_MODE="cpu"; fi
    info "PyTorch build: $TORCH_MODE (auto-selected)"
fi

remote_size() {
    curl -sIL --max-time 30 "$1" | awk 'tolower($1)=="content-length:" {v=$2} END {gsub("\r","",v); print v}'
}
file_size() { stat -c %s "$1" 2>/dev/null || echo 0; }

carla_extracted() { [ -x "$CARLA_ROOT/CarlaUE4.sh" ] && [ "$(cat "$CARLA_ROOT/VERSION" 2>/dev/null)" = "$CARLA_VERSION" ]; }
# The base package already contains Town06's OpenDRIVE/nav data; only the
# additional maps archive contains the map itself.
maps_extracted()  { [ -f "$CARLA_ROOT/CarlaUE4/Content/Carla/Maps/Town06.umap" ]; }

# --- 2. conda --------------------------------------------------------------

step "Conda"

CONDA_BASE=""
for d in "$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3"; do
    if [ -f "$d/etc/profile.d/conda.sh" ]; then CONDA_BASE="$d"; break; fi
done
if [ -z "$CONDA_BASE" ] && command -v conda >/dev/null; then
    CONDA_BASE="$(conda info --base 2>/dev/null || true)"
fi
if [ -z "$CONDA_BASE" ] || [ ! -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
    info "conda not found; installing Miniforge into ~/miniforge3"
    curl -fsSL --retry 3 -o "$DL_DIR/Miniforge3.sh" "$MINIFORGE_URL"
    bash "$DL_DIR/Miniforge3.sh" -b -p "$HOME/miniforge3" >/dev/null
    CONDA_BASE="$HOME/miniforge3"
    MINIFORGE_INSTALLED=1
fi
# shellcheck disable=SC1091
. "$CONDA_BASE/etc/profile.d/conda.sh"
info "Using conda at $CONDA_BASE ($(conda --version))"

env_exists() { grep -qx "$1" <<<"$(conda env list | awk '{print $1}')"; }
port_in_use() { grep -q ':2000 ' <<<"$(ss -ltn 2>/dev/null)"; }

step "Disk space"
need=0
if ! carla_extracted; then
    [ -f "$DL_DIR/CARLA_$CARLA_VERSION.tar.gz" ] || need=$((need + SIZE_CARLA_ARCHIVE))
    need=$((need + SIZE_CARLA_EXTRACTED))
fi
if [ "$WITH_MAPS" = 1 ] && ! maps_extracted; then
    [ -f "$DL_DIR/AdditionalMaps_$CARLA_VERSION.tar.gz" ] || need=$((need + SIZE_MAPS_ARCHIVE))
    need=$((need + SIZE_MAPS_EXTRACTED))
fi
env_exists "$ENV_NAME" || need=$((need + SIZE_PY_ENV))
if [ "$WITH_ROS2" = 1 ] && ! env_exists "$ROS_ENV_NAME"; then need=$((need + SIZE_ROS_ENV)); fi
free="$(df -BG --output=avail "$INSTALL_DIR" | tail -1 | tr -dc '0-9')"
info "Disk: ${free} GiB free, about ${need} GiB needed"
[ "$free" -ge "$need" ] || die "not enough free disk space in $INSTALL_DIR (${free} GiB free, ~${need} GiB needed). Use --no-maps or --dir to choose another location."

# --- 3. download -----------------------------------------------------------

download() {  # url dest
    local url="$1" dest="$2" name want have
    name="$(basename "$dest")"
    want="$(remote_size "$url")"
    [ -n "$want" ] || die "cannot reach $url"
    have="$(file_size "$dest")"
    if [ "$have" = "$want" ]; then
        info "$name: already downloaded"
        return 0
    fi
    if [ "$have" -gt "$want" ]; then rm -f "$dest"; have=0; fi
    if [ "$have" -gt 0 ]; then
        info "$name: resuming at $((have / 1048576)) of $((want / 1048576)) MB"
    else
        info "$name: downloading $((want / 1048576)) MB"
    fi
    for attempt in 1 2 3; do
        rc=0
        curl -fL --retry 5 --retry-delay 10 -C - --progress-bar -o "$dest" "$url" || rc=$?
        [ "$rc" = 0 ] && break
        if [ "$rc" = 33 ]; then
            # The server refused to resume (no byte-range support on this request).
            warn "the server would not resume $name; restarting it from the beginning"
            rm -f "$dest"
        else
            warn "download interrupted (curl exit $rc, attempt $attempt of 3); resuming"
        fi
        sleep 5
    done
    have="$(file_size "$dest")"
    [ "$have" = "$want" ] || die "$name is incomplete ($have of $want bytes). Re-run the installer to resume."
    info "$name: complete"
}

step "Downloading CARLA $CARLA_VERSION"
if carla_extracted; then
    info "CARLA already installed in $CARLA_ROOT"
else
    download "$CARLA_URL" "$DL_DIR/CARLA_$CARLA_VERSION.tar.gz"
fi
if [ "$WITH_MAPS" = 1 ]; then
    if maps_extracted; then
        info "Additional maps already installed"
    else
        download "$MAPS_URL" "$DL_DIR/AdditionalMaps_$CARLA_VERSION.tar.gz"
    fi
fi

# --- 4. extract ------------------------------------------------------------

step "Extracting"
mkdir -p "$CARLA_ROOT"
if carla_extracted; then
    info "CARLA: already extracted"
else
    info "CARLA: extracting (several minutes)"
    tar -xzf "$DL_DIR/CARLA_$CARLA_VERSION.tar.gz" -C "$CARLA_ROOT"
    carla_extracted || die "extraction finished but $CARLA_ROOT/CarlaUE4.sh or VERSION is missing"
    info "CARLA: done"
fi
if [ "$WITH_MAPS" = 1 ]; then
    if maps_extracted; then
        info "Additional maps: already extracted"
    else
        info "Additional maps: extracting (several minutes)"
        tar -xzf "$DL_DIR/AdditionalMaps_$CARLA_VERSION.tar.gz" -C "$CARLA_ROOT"
        maps_extracted || die "map extraction finished but Town06 is missing"
        info "Additional maps: done"
    fi
fi
if [ "$REMOVE_ARCHIVES" = 1 ]; then
    rm -f "$DL_DIR/CARLA_$CARLA_VERSION.tar.gz" "$DL_DIR/AdditionalMaps_$CARLA_VERSION.tar.gz"
    info "Removed downloaded archives"
fi

# --- 5. ScenarioRunner -----------------------------------------------------

step "ScenarioRunner $SR_TAG"
if [ -d "$SR_DIR/.git" ]; then
    tag="$(git -C "$SR_DIR" describe --tags --exact-match 2>/dev/null || true)"
    if [ "$tag" = "$SR_TAG" ]; then
        info "Already cloned at $SR_TAG"
    else
        warn "$SR_DIR exists at '${tag:-an untagged commit}', expected $SR_TAG; leaving it unchanged"
    fi
else
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$SR_TAG" "$SR_REPO" "$SR_DIR"
    info "Cloned into $SR_DIR"
fi

# --- 6. Python environment -------------------------------------------------

step "Python environment '$ENV_NAME'"
if env_exists "$ENV_NAME"; then
    conda activate "$ENV_NAME"
    if [ -f "$CONDA_PREFIX/$ENV_MARKER" ]; then
        info "Environment exists"
    elif [ "$REUSE_ENV" = 1 ]; then
        touch "$CONDA_PREFIX/$ENV_MARKER"
        info "Using existing environment (--reuse-env)"
    else
        die "a conda environment named '$ENV_NAME' already exists and was not created by this installer. Installing into it would change its packages (for example, numpy would be set to 1.24.4). Use --env <new-name> for a separate environment, or --reuse-env to install into it anyway."
    fi
else
    conda create -y -q -n "$ENV_NAME" "python=$PYTHON_VERSION" >/dev/null
    conda activate "$ENV_NAME"
    touch "$CONDA_PREFIX/$ENV_MARKER"
    info "Created with Python $PYTHON_VERSION"
fi
py_ver="$(python -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
[ "$py_ver" = "$PYTHON_VERSION" ] || die "environment '$ENV_NAME' uses Python $py_ver; Python $PYTHON_VERSION is required. Remove it or choose another name with --env."

PIP=(python -m pip install --disable-pip-version-check)
info "Installing CARLA client, example, and ScenarioRunner dependencies"
"${PIP[@]}" -q "carla==$CARLA_VERSION" -r "$SETUP_DIR/requirements-examples.txt" -r "$SR_DIR/requirements.txt"
python -m pip check >/dev/null || die "dependency conflict in '$ENV_NAME' (run: conda activate $ENV_NAME && pip check)"
info "Dependencies installed"

# --- 7. PyTorch ------------------------------------------------------------

step "PyTorch ($TORCH_MODE)"
TORCH_RESULT="not installed"
torch_ok() {  # mode
    python - "$1" <<'EOF' 2>/dev/null
import sys, torch
mode = sys.argv[1]
ok = torch.__version__.startswith("2.8.0") and ((torch.version.cuda is not None) == (mode == "cuda"))
sys.exit(0 if ok else 1)
EOF
}
case "$TORCH_MODE" in
    none)
        info "Skipped"
        ;;
    cuda|cpu)
        if torch_ok "$TORCH_MODE"; then
            info "PyTorch $TORCH_VERSION ($TORCH_MODE) already installed"
        elif [ "$TORCH_MODE" = "cpu" ]; then
            "${PIP[@]}" "torch==$TORCH_VERSION" "torchvision==$TORCHVISION_VERSION" --index-url "$TORCH_INDEX/cpu"
        elif curl -sfI --max-time 15 "$NVIDIA_INDEX_PROBE" >/dev/null; then
            "${PIP[@]}" "torch==$TORCH_VERSION" "torchvision==$TORCHVISION_VERSION" --index-url "$TORCH_INDEX/cu128"
        else
            warn "pypi.nvidia.com is unreachable; installing the CUDA libraries from PyPI instead"
            "${PIP[@]}" -r "$SETUP_DIR/nvidia-cu12-reqs.txt" --index-url https://pypi.org/simple
            "${PIP[@]}" "torch==$TORCH_VERSION" "torchvision==$TORCHVISION_VERSION" \
                --index-url "$TORCH_INDEX/cu128" --extra-index-url https://pypi.org/simple
        fi
        TORCH_RESULT="$(python -c 'import torch; print(f"{torch.__version__}, CUDA available: {torch.cuda.is_available()}")')"
        info "PyTorch $TORCH_RESULT"
        if [ "$TORCH_MODE" = "cuda" ] && ! python -c 'import torch, sys; sys.exit(0 if torch.cuda.is_available() else 1)'; then
            warn "PyTorch was installed but cannot see the GPU; check the NVIDIA driver"
        fi
        ;;
esac

# --- 8. ROS 2 (optional) ---------------------------------------------------

ROS_RESULT="not requested"
if [ "$WITH_ROS2" = 1 ]; then
    step "ROS 2 Humble ('$ROS_ENV_NAME')"
    conda deactivate
    if env_exists "$ROS_ENV_NAME" && grep -q '^ros-humble-desktop ' <<<"$(conda list -n "$ROS_ENV_NAME" 2>/dev/null)"; then
        info "Already installed"
    elif env_exists "$ROS_ENV_NAME"; then
        die "environment '$ROS_ENV_NAME' exists but does not contain ROS 2. Remove it (conda env remove -n $ROS_ENV_NAME) or choose another name with --ros-env."
    else
        info "Installing ros-humble-desktop (several minutes)"
        # Create the env and install ROS in one transaction. Installing ROS
        # into an existing env fails in a package post-link step.
        conda create -y -q -n "$ROS_ENV_NAME" -c robostack-humble -c conda-forge \
            "python=$PYTHON_VERSION" ros-humble-desktop >/dev/null
    fi
    conda run -n "$ROS_ENV_NAME" python -c "import rclpy" || die "ROS 2 installed but 'import rclpy' failed in '$ROS_ENV_NAME'"
    ROS_RESULT="installed in '$ROS_ENV_NAME'"
    info "ROS 2 OK"
    conda activate "$ENV_NAME"
fi

# --- 9. helper scripts -----------------------------------------------------

step "Helper scripts"
# Copy src to dest. The two shell helpers are pointed at this install location
# and environment when they differ from the defaults (~/carla-sim, env
# "carla"). An existing dest that differs from the new version is kept as
# <dest>.bak.
CUSTOMIZE=0
if [ "$INSTALL_DIR" != "$HOME/carla-sim" ] || [ "$ENV_NAME" != "carla" ]; then CUSTOMIZE=1; fi
dir_esc="$(printf '%s' "$INSTALL_DIR" | sed 's/[\\&|]/\\&/g')"
install_file() {  # src dest
    local src="$1" dest="$2" tmp="$2.new"
    cp "$src" "$tmp"
    if [ "$CUSTOMIZE" = 1 ] && [[ "$dest" == *.sh ]]; then
        sed -i -e "s|\$HOME/carla-sim|$dir_esc|g" -e "s|CARLA_CONDA_ENV:-carla}|CARLA_CONDA_ENV:-$ENV_NAME}|" "$tmp"
    fi
    if [ -f "$dest" ] && ! cmp -s "$tmp" "$dest"; then
        mv "$dest" "$dest.bak"
        info "Kept your previous $(basename "$dest") as $(basename "$dest").bak"
    fi
    mv "$tmp" "$dest"
}
mkdir -p "$INSTALL_DIR/smoketest"
install_file "$SETUP_DIR/linux/setup_env.sh" "$INSTALL_DIR/setup_env.sh"
install_file "$SETUP_DIR/linux/launch_carla.sh" "$INSTALL_DIR/launch_carla.sh"
chmod +x "$INSTALL_DIR/launch_carla.sh"
for f in "$SETUP_DIR/smoketest/"*.py; do
    install_file "$f" "$INSTALL_DIR/smoketest/$(basename "$f")"
done
info "Installed setup_env.sh, launch_carla.sh, and smoketest/ into $INSTALL_DIR"

# --- 10. smoke test --------------------------------------------------------

SMOKE_RESULT="skipped"
SMOKE_FAILED=0
if [ "$RUN_SMOKETEST" = 1 ]; then
    step "Smoke test"
    if port_in_use; then
        warn "port 2000 is in use (is CARLA already running?); skipping the smoke test"
        SMOKE_RESULT="skipped (port 2000 in use)"
    else
        pidfile="$LOG_DIR/.smoketest-server.pid"
        rm -f "$pidfile"
        # The server runs in its own session so Ctrl+C reaches only this
        # script, whose trap stops it. $! is recorded immediately so an
        # interrupt at any point after launch can stop the server; it equals
        # the session's process group ID because setsid does not fork when
        # called from a background job of a non-interactive shell.
        CARLA_ROOT="$CARLA_ROOT" setsid bash -c 'echo $$ > "$1"; exec "$2" --offscreen' _ \
            "$pidfile" "$INSTALL_DIR/launch_carla.sh" > "$LOG_DIR/smoketest-server.log" 2>&1 &
        SERVER_PGID="$!"
        for _ in $(seq 1 50); do [ -s "$pidfile" ] && break; sleep 0.1; done
        [ -s "$pidfile" ] && SERVER_PGID="$(cat "$pidfile")"
        info "Starting CARLA headless (allow up to 3 minutes on first launch)"
        up=0
        for _ in $(seq 1 180); do
            if port_in_use; then up=1; break; fi
            kill -0 "$SERVER_PGID" 2>/dev/null || break
            sleep 1
        done
        if [ "$up" = 1 ] && python "$INSTALL_DIR/smoketest/carla_smoketest.py" \
                --town Town10HD_Opt --out "$LOG_DIR/smoketest-frame.png"; then
            SMOKE_RESULT="passed (frame saved to $LOG_DIR/smoketest-frame.png)"
        else
            [ "$up" = 1 ] || { warn "the CARLA server did not start. Last lines of its log:"; tail -15 "$LOG_DIR/smoketest-server.log" >&2; }
            SMOKE_RESULT="FAILED (see $LOG_DIR/smoketest-server.log)"
            SMOKE_FAILED=1
        fi
        stop_server
    fi
fi

# --- summary ---------------------------------------------------------------

cat <<EOF

==> Installation summary
    CARLA:          $CARLA_ROOT$( [ "$WITH_MAPS" = 1 ] && echo " (with additional maps)")
    ScenarioRunner: $SR_DIR
    Python env:     $ENV_NAME (Python $PYTHON_VERSION)
    PyTorch:        $TORCH_RESULT
    ROS 2:          $ROS_RESULT
    Smoke test:     $SMOKE_RESULT
    Elapsed:        $((SECONDS / 60)) min $((SECONDS % 60)) s

Next steps:
    source $INSTALL_DIR/setup_env.sh      # in each new terminal
    $INSTALL_DIR/launch_carla.sh          # start the simulator
EOF
if [ "${MINIFORGE_INSTALLED:-0}" = 1 ]; then
    echo "    Miniforge was installed. Run '~/miniforge3/bin/conda init' to use conda in new shells."
fi
exit "$SMOKE_FAILED"

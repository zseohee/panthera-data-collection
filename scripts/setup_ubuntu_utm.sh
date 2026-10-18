#!/usr/bin/env bash
# Ubuntu 24.04 ARM64 setup. Run after installing apt packages in README.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk="$root/dependencies/Panthera-HT_SDK"
teleop="$root/dependencies/QuestTelePanthera"
lerobot="$root/dependencies/Panthera-HT_lerobot"
venv="$root/.venv"
with_lerobot=0

if [[ "${1:-}" == "--with-lerobot" ]]; then
  with_lerobot=1
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--with-lerobot]" >&2
  exit 2
fi

for tool in cmake c++ pkg-config; do
  command -v "$tool" >/dev/null || { echo "Missing $tool; install apt packages first" >&2; exit 1; }
done
test -f "$sdk/panthera_python/setup.py" || { echo "Missing SDK submodule; run git submodule update --init --recursive" >&2; exit 1; }
test -f "$teleop/pyproject.toml" || { echo "Missing Quest submodule; run git submodule update --init --recursive" >&2; exit 1; }

if [[ $with_lerobot -eq 1 ]]; then
  bash "$root/scripts/apply-compat-patches.sh" --with-lerobot
else
  bash "$root/scripts/apply-compat-patches.sh"
fi

python3 -m venv "$venv"
source "$venv/bin/activate"
python -m pip install -U pip 'setuptools<81' wheel pybind11

if ! python -c 'import hightorque_robot' >/dev/null 2>&1; then
  cmake -S "$sdk/panthera_cpp/motor_cpp" -B "$sdk/panthera_cpp/motor_cpp/build" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$VIRTUAL_ENV"
  cmake --build "$sdk/panthera_cpp/motor_cpp/build" -j"$(nproc)"
  cmake --install "$sdk/panthera_cpp/motor_cpp/build"
fi
CMAKE_PREFIX_PATH="$VIRTUAL_ENV" python -m pip install -e "$sdk/panthera_python" --no-build-isolation --no-deps
python -m pip install -r "$sdk/panthera_python/requirements.txt" 'numpy<2'
python -m pip install -e "${teleop}[relay,panthera]" 'numpy<2'

if [[ $with_lerobot -eq 1 ]]; then
  python -m pip install -e "$lerobot/lerobot" -e "$lerobot/Panthera-HT_robot_lerobot" 'numpy<2'
fi

python -c 'import hightorque_robot, pinocchio, yaml; print("SDK imports OK")'
python "$teleop/tools/selftest_panthera_ik.py" "$sdk/panthera_python/Panthera-HT_description/urdf/Panthera-HT_description_follower.urdf"
python "$teleop/tools/selftest_panthera_gripper.py"
echo "Setup complete. Run: source '$venv/bin/activate'"
echo "Run: export PANTHERA_SDK_DIR='$sdk/panthera_python'"

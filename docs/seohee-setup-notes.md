# Panthera-HT on Seohee's Ubuntu 24.04 ARM64 UTM VM

> Historical machine-specific notes. For a fresh team clone, start with the
> [workspace README](../README.md). Paths beginning `~/Panthera-HT_SDK` or
> `~/QuestTelePanthera` below refer to the original unpacked folders; use the
> corresponding `dependencies/` paths in this repository.

For the observed USB, Quest, arm-port, and recording issues, see
`~/PANTHERA_UTM_README.md`.

For the Mac development + Ubuntu hardware workflow, follow
`~/PANTHERA_MAC_VM_SPLIT.md` after completing the software installation.

The source archives are already unpacked as `~/Panthera-HT_SDK` and
`~/QuestTelePanthera`. The vendor quick start is at
`~/Panthera-HT_Quick_Start_Guide_A5.pdf`. The SDK wheels are x86_64, so use
the source build below. QuestTelePanthera lists x86_64 as its tested platform;
its Quest-to-arm dry run was verified on this ARM64 VM. Live movement and
camera-inclusive recording still need verification.

## 1. Install system packages

Run this in your Ubuntu terminal so you can enter your sudo password locally:

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libglib2.0-dev \
  libyaml-cpp-dev libserialport-dev python3.12-venv python3.12-dev git adb
```

Then run:

```bash
bash ~/setup_panthera_utm.sh
source ~/.venvs/panthera/bin/activate
export PANTHERA_SDK_DIR="$HOME/Panthera-HT_SDK/panthera_python"
```

The script builds the motor C++ library and Python binding inside the local
venv, installs the SDK and Quest package, then runs import and IK checks. It
does not connect to or move the arm. If it fails, retain the terminal output.

## 2. Pass the USB devices into UTM

UTM's USB sharing requires its QEMU backend. Enable USB sharing in the VM's
settings. With the VM running, attach the comm board (and separately the Quest
and USB webcam) using UTM's USB toolbar menu. The Mac's built-in camera may
not be available for passthrough; use a USB webcam. In Ubuntu, check:

```bash
lsusb
ls -l /dev/ttyACM* /dev/video* 2>&1
```

The comm board normally exposes seven `/dev/ttyACM*` nodes. If the nodes
exist but access is denied, check `ls -l /dev/ttyACM0` and add your user to
the device's group (often `dialout`), then log out and back in. Avoid the
vendor README's world-writable `chmod 777` example.

## 3. Check the arm before enabling motion

Read the quick start and secure the arm to the bench. The arm has no holding
brakes; keep it supported and the workspace clear. After the comm board and
arm power are connected, run from `~/QuestTelePanthera`:

```bash
source ~/.venvs/panthera/bin/activate
export PANTHERA_SDK_DIR="$HOME/Panthera-HT_SDK/panthera_python"
cd ~/QuestTelePanthera
bash tools/scan_ports.sh
```

The scanner is read-only and restores the vendor YAML. Look for `*** MOTORS
LIVE ***`; seeing `id:00 v0.0.0` is not proof of a working port. Use the
number the scanner reports, for example:

```bash
python -m vr_teleop_kit.panthera.arm_config right 3
python -m vr_teleop_kit.panthera.probe robot_param/Follower_right.yaml
```

Replace `3` with the actual live port number.

## 4. Quest dry run, then motion

The Quest 3/3S needs Developer Mode and USB debugging. Attach it to UTM,
accept the headset's USB debugging prompt, then run:

```bash
cd ~/QuestTelePanthera
python tools/quest_link.py
tools/start_panthera_teleop.sh
```

Open `http://localhost:8443/` in the Quest browser, press **Start Teleop**,
and squeeze the grip. The launcher above only logs targets. Once the target
mapping and port are correct, follow `docs/PANTHERA.md` and deliberately run
`ENABLE=1 tools/start_panthera_teleop.sh` to command motors. Park the arm
before removing power.

## 5. Recording and camera

The Quest bridge's `--record PATH` saves commanded joint trajectories as
JSONL. It does not by itself create a LeRobot camera dataset. For image data,
attach a USB webcam to UTM and, after LeRobot is installed, identify it with:

```bash
lerobot-find-cameras opencv
```

The vendor's bundled LeRobot recorder and Panthera adapter are installed in
the same venv. `lerobot-find-cameras opencv` and `lerobot-record --help` work
without hardware. The local LeRobot copy is configured for headless use
because its optional Rerun viewer requires NumPy 2 while the motor SDK
requires NumPy 1. The Panthera follower defaults to no cameras; pass an
explicit OpenCV camera config after discovering the device path or index.

Use the discovered OpenCV camera path or index in the Panthera LeRobot robot
config. HighTorque's LeRobot repository documents
`--robot.type=panthera_follower` and `--teleop.type=panthera_leader` for a
leader arm. The Quest package's generic LeRobot teleoperators target a
different robot's joint names and do not yet register as a Panthera teleop in
`lerobot-record`. Do not use the leader value for Quest. For Quest control,
follow `docs/PANTHERA.md` and record the bridge's JSONL trajectory until a
Panthera-specific LeRobot teleoperator is built and checked on hardware.

The dataset README says to upload a validated local folder using:

```bash
hf auth login
hf upload WiscoHumanoidsLab/actuator_assembly path/to/folder --repo-type dataset
```

Only upload once the data contents and repository permissions are confirmed.

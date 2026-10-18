# Panthera-HT data collection workspace

One place for our Panthera-HT SDK, Quest teleoperation, LeRobot integration, vendor quick-start guide, and UTM setup notes. The four code/documentation repositories are **Git submodules pinned to specific upstream commits**. Their source is not copied into this repository or committed with local edits.

| Path | Purpose | Upstream |
| --- | --- | --- |
| `dependencies/Panthera-HT_SDK` | Motor SDK and robot parameters | [HighTorque SDK](https://github.com/HighTorque-Robotics/Panthera-HT_SDK) |
| `dependencies/QuestTelePanthera` | Quest relay and Panthera bridge | [QuestTelePanthera](https://github.com/ggao50/QuestTelePanthera) |
| `dependencies/Panthera-HT_lerobot` | Panthera LeRobot adapter and bundled LeRobot | [HighTorque LeRobot](https://github.com/HighTorque-Robotics/Panthera-HT_lerobot) |
| `dependencies/Panthera-HT_Main` | Vendor safety and quick-start documents | [HighTorque Main](https://github.com/HighTorque-Robotics/Panthera-HT_Main) |

## Get the workspace

After this repository is published, teammates can run:

```bash
git clone --recurse-submodules <TEAM_REPO_URL> panthera-data-collection
cd panthera-data-collection
```

If it was cloned without the flag, run `git submodule update --init --recursive`. Do **not** run `git submodule update --remote` for a reproducible setup; that changes the pinned versions.

## Ubuntu 24.04 ARM64 in UTM

Read the [vendor quick-start guide](dependencies/Panthera-HT_Main/documents/Panthera-HT_Quick_Start_Guide_A5.pdf) before connecting or powering the arm. Install system packages once:

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libglib2.0-dev \
  libyaml-cpp-dev libserialport-dev python3.12-venv python3.12-dev git adb
```

Then, from this repository's root:

```bash
bash scripts/setup_ubuntu_utm.sh --with-lerobot
source .venv/bin/activate
export PANTHERA_SDK_DIR="$PWD/dependencies/Panthera-HT_SDK/panthera_python"
```

The script compiles the SDK, installs the Quest package, and optionally installs LeRobot with `--with-lerobot`. It applies the documented [local compatibility patches](patches/) to the **working copies** of two submodules for the current ARM64/headless setup. The parent repository still pins untouched upstream commits. `git status --ignore-submodules=none` will show those two local submodules as modified after setup. Run `git submodule foreach 'git reset --hard HEAD'` only if you intentionally want to discard those patches and any other local edits in *all* dependencies.

The patches preserve fixes that were present in the original local folders: Hatch direct-reference metadata for Quest installation, and optional no-RealSense/headless behavior in the LeRobot fork. They are separate from upstream and should be reviewed when upgrading submodule commits. The script does not move the robot.

## Connect and check hardware

Pass the Livelybot communication board, Quest, and USB webcam **separately** into the Ubuntu VM using UTM's USB menu. USB Sharing being enabled does not attach a device by itself. Activate the venv and set `PANTHERA_SDK_DIR` in each new terminal, then follow the [Panthera-specific Quest guide](dependencies/QuestTelePanthera/docs/PANTHERA.md). Run its `tools/scan_ports.sh` to find the powered arm's live `/dev/ttyACM<N>` port; port numbers can change after USB reconnects. Generate each arm config with `python -m vr_teleop_kit.panthera.arm_config <left|right> <N>` and run the read-only probe before enabling motors.

Serial ports normally belong to `dialout`. The **current terminal** must show `dialout` in `id -nG`; if the account was just added to that group, log out and back in or start a new shell with `newgrp dialout`. A Python venv prompt alone does not grant serial access. The vendor SDK may segfault after a port-open failure.

Quest USB setup: `adb devices` must show `device`, then run `adb reverse tcp:8443 tcp:8443`. Open `http://localhost:8443/` in **Quest Browser** while the relay runs. The Quest bridge is a **dry run by default**. Enable physical motion only after the correct arm/port, free workspace, and motor probe are verified; the arm has no holding brakes. See [Seohee's observed troubleshooting notes](docs/seohee-troubleshooting.md) for the exact checks used on the original UTM VM. Those notes refer to older `~/...` paths; substitute this repository's `dependencies/...` paths.

## Camera and data status

Use `lerobot-find-cameras opencv` after the USB webcam appears in both `lsusb` and `/dev/video*`. The Quest relay's camera stream is for viewing; its bridge `--record` option writes joint-trajectory JSONL **without images**. Quest-to-Panthera movement and a camera-inclusive LeRobot dataset have not yet been verified in this workspace. The vendor LeRobot examples document a leader-arm teleoperator, not Quest as a Panthera LeRobot teleoperator. Do not label a JSONL trajectory as the final camera dataset.

Keep recordings, credentials, certificates, and locally generated arm configs out of Git. `data/` and `recordings/` are ignored. The intended dataset destination is [WiscoHumanoidsLab/actuator_assembly](https://huggingface.co/datasets/WiscoHumanoidsLab/actuator_assembly); check its README and validate a complete dataset before upload.

## Updating a dependency

In a separate review, update one submodule, retest the local patches and hardware workflow, then commit its new gitlink in this parent repository. Teammates receive the exact reviewed version with `git pull && git submodule update --init --recursive`.

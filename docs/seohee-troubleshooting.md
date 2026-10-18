# Panthera-HT + Quest on Seohee's Ubuntu UTM VM

> Historical machine-specific notes. For a fresh team clone, start with the
> [workspace README](../README.md). The `~/...` paths below refer to the
> original VM folders, not this repository's `dependencies/` directory.

Troubleshooting notes from October 17, 2026. Installation steps are in `~/PANTHERA_SETUP_UTM.md`. For hardware safety and VR controls, see `~/Panthera-HT_Quick_Start_Guide_A5.pdf` and `~/QuestTelePanthera/docs/PANTHERA.md`.

## Verified status

- The Quest is visible to ADB. `adb reverse tcp:8443 tcp:8443` returned `8443`, the Quest Browser opened `http://localhost:8443/`, and the relay received `xr_frame` messages.
- The Livelybot communication board (`caf1:ffff`) exposed seven serial nodes. The powered arm answered on **`/dev/ttyACM1`**. `robot_param/Follower_right.yaml` was created with `serial_id: 1`. Its probe reported all seven motors connected and six real arm-joint positions.
- A right-hand **dry run** connected the arm and Quest. Logs showed `engage`, changing `dry` joint targets, `disengage`, and matching position/orientation mappings. `0 arm writes` was expected because motors were disabled.
- **Not yet verified:** successful physical movement with the live bridge, a nonempty recorded episode, camera recording, or LeRobot dataset creation. Confirm that the arm on `ttyACM1` is physically the right arm. The other arm has not been configured. A later camera check found no camera in the VM's `lsusb` and no `/dev/video*` nodes, so OpenCV discovery reported no cameras.

## Problems and fixes

### UTM USB sharing ran out of slots

UTM reported no room for another USB channel while the arm board, webcam, Quest, and a microSD reader were connected. The exact action that cleared this error was not recorded. If it recurs, detach the unnecessary reader or shut down the VM and raise **Input → USB Sharing → Maximum Shared Devices**. Attach the Quest to the Ubuntu VM with UTM's USB menu.

### `adb devices` said `no permissions`

Ubuntu detected the Quest but the user lacked USB access. The Meta vendor-ID `udev` rule was added:

```bash
printf '%s\n' 'SUBSYSTEM=="usb", ATTR{idVendor}=="2833", MODE="0660", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/51-meta-quest.rules >/dev/null
sudo udevadm control --reload-rules
```

After changing a rule, **detach and reattach Quest in UTM**. Wear the headset and approve **Allow USB debugging**. `adb devices` must end in `device`, not `no permissions` or `unauthorized`. Then run `adb reverse tcp:8443 tcp:8443`. Repeat the reverse command after a Quest USB reconnect. Open the URL in **Quest Browser**, not on the Mac.

### `/dev/ttyACM0`–`6` existed, but the scan found no motors

The USB communication board exposes seven ports even if the arm is off. Before arm power was on, the probe printed motor-disconnected messages and `999.000` for all six joints; `999` is an invalid reading. After powering the arm and obtaining serial access, `bash tools/scan_ports.sh` found `ttyACM1 *** MOTORS LIVE ***` with six real positions. Those six values are joint angles in radians; `ttyACM1` is the USB port, not a motor number. The seventh motor is the gripper.

Rescan after reconnecting the communication board because `/dev/ttyACM` numbering may change. The scan restores the vendor YAML when it finishes.

### `Motor Unable to open port` / `PortNotOpenedException` / segfault

`/dev/ttyACM1` was `root:dialout` with mode `crw-rw----`. New Ubuntu terminals lacked the `dialout` group, even when their prompt showed the Python venv `(panthera)`. The vendor SDK can segfault after it fails to open the serial port. `fuser` showed no competing process in the checked case.

The account was added permanently with `sudo usermod -aG dialout "$USER"`. A full Ubuntu logout/login makes this effective in new terminals. For an immediate fix in the **exact terminal used for the arm bridge**, run `newgrp dialout`, **wait for the new prompt**, then run `id -nG` separately and confirm `dialout` appears. `newgrp` starts a nested shell: commands pasted after it may wait until that shell exits. Activate the venv again in that new shell.

Before live control, check from that same terminal:

```bash
id -nG
cd ~/QuestTelePanthera
source ~/.venvs/panthera/bin/activate
python -m vr_teleop_kit.panthera.probe robot_param/Follower_right.yaml
```

Proceed only after `Motors responding with real values!`. If the port still fails, check `sudo fuser -v /dev/ttyACM1` and stop any old bridge or probe in its own terminal. Only one arm process should own the port.

### Quest tracking worked but the real arm did not move

`bash tools/start_panthera_teleop.sh` is a **dry run** by default. `motors DISABLED`, `dry` logs, and `0 arm writes` mean Quest tracking and IK work but nothing is sent to the motors. On the Quest page, press **Start Teleop** and hold the right controller's **grip** while moving that controller; headset motion alone does not command the arm. `disengage` means the grip was released, not that the launcher ended. Press Ctrl+C in the launcher terminal to stop it. Stop any earlier standalone `vr-teleop-relay` before using the launcher because both bind port 8443.

## Next short live-recording test

Confirm `ttyACM1` is physically the right arm. Secure and support it, clear the workspace, and keep the power control accessible. The arm has no holding brakes. Keep one relay running in another Ubuntu terminal: `vr-teleop-relay --host localhost --port 8443`. In the **same `dialout` terminal that passed the probe**, run the following. It commands a move to the all-zero park pose **at startup** and parks there again on Ctrl+C:

```bash
cd ~/QuestTelePanthera
source ~/.venvs/panthera/bin/activate
mkdir -p "$HOME/panthera_data"
record_file="$HOME/panthera_data/episode_$(date +%Y%m%d_%H%M%S).jsonl"
echo "Recording to: $record_file"
python -m vr_teleop_kit.panthera.bridge \
  --hand right --config robot_param/Follower_right.yaml \
  --ws-url ws://127.0.0.1:8443/ws \
  --enable-motors --gripper \
  --park-on-start --park-on-exit --park-pose 0 0 0 0 0 0 \
  --park-speed 0.1 --speed-fraction 0.1 \
  --write-mode mit --friction-ff --reset-hand left \
  --record "$record_file"
```

Refresh the Quest page, press **Start Teleop**, and hold the right grip while moving its controller. Release the grip to pause. Stop the bridge with Ctrl+C; wait for parking and the saved-file message before removing arm power. `wc -l "$record_file"` should be nonzero after a recording. A failed bridge startup does not produce useful episode data.

## Camera and final dataset remain open

The USB webcam (`32e4:9230`) appeared in an earlier `lsusb` listing. In later checks, `lsusb | grep -iE '32e4|camera'` returned nothing, `ls -l /dev/video*` found no devices, and `lerobot-find-cameras opencv` reported no cameras. `sudo modprobe uvcvideo` did not create a video node. The latest full `lsusb` still shows the Livelybot board (`caf1:ffff`), microSD reader (`05e3:0751`), and Dell DA20 adapter (`413c:b080`), but **neither the webcam nor the Quest**. The webcam is currently not attached to the Ubuntu VM; this is upstream of OpenCV. The exact reason it detached has not been identified. The Quest being absent is expected while it is charging separately, but USB Quest teleoperation will need it attached again.

The camera's USB **data** cable must connect to the Mac or a Mac-connected USB hub; motor communication through the Livelybot board does not provide camera video. Then attach **HD USB Camera** in UTM's USB menu. Enabling USB Sharing alone does not attach the device. If UTM has no free USB-sharing slot, detach the microSD reader or raise the VM's Maximum Shared Devices setting while the VM is shut down. Then verify `lsusb | grep -iE '32e4|camera'` and `ls -l /dev/video*`. If the webcam appears in `lsusb` but `/dev/video*` is still absent, check `lsusb -t` and `sudo dmesg | tail -n 50` for driver errors. Once a video device appears, rerun `lerobot-find-cameras opencv`.

`camera ... env var unset, skipping` means the VR relay did not stream a camera. Even if configured, its camera stream does **not** add images to the bridge's `--record` file.

`--record` produces commanded joint trajectory JSONL (`t`, `pos`, `vel`, optional `gripper_pos`), **not a camera-inclusive LeRobot dataset**. The current Quest LeRobot adapter targets another arm's joint names and is not registered as a Panthera teleoperator in `lerobot-record`. Build and validate the camera + Panthera recording path before treating a trajectory file as the final dataset or uploading it to Hugging Face.

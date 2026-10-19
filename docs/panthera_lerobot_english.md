# Panthera-HT LeRobot Usage Guide

This document describes common Panthera-HT workflows after integration with LeRobot, including environment setup, data collection, training, evaluation, dataset visualization, and camera configuration.

## 1. Environment Setup

Create the environment:

```bash
conda create -n lerobot python=3.10
conda activate lerobot
```

Install LeRobot and the Panthera-HT adapter package:

```bash
cd ~/Panthera-HT/Panthera-HT_lerobot
pip install -e lerobot
pip install -e Panthera-HT_robot_lerobot
```

Install commonly used dependencies:

```bash
pip install pynput pin pyrealsense2
```

Verify the installation:

```bash
lerobot-find-cameras realsense
cd lerobot/src/lerobot/scripts
python lerobot_record.py --help
```

## 2. Working Directory

The following data collection, training, and evaluation commands assume that you are running them from the LeRobot scripts directory:

```bash
cd ~/Panthera-HT/Panthera-HT_lerobot/lerobot/src/lerobot/scripts
```

## 3. Data Collection

### 3.1 Leader-Follower Mode

Use this mode when you have one Leader arm and one Follower arm. The Leader arm is manually moved by the operator, while the Follower arm tracks the Leader's motion and records robot states and camera images.

```bash
python lerobot_record.py \
  --robot.type=panthera_follower \
  --teleop.type=panthera_leader \
  --dataset.repo_id=local/panthera_demo \
  --dataset.single_task="panthera_demo_task" \
  --dataset.num_episodes=20 \
  --dataset.episode_time_s=30 \
  --dataset.reset_time_s=60 \
  --dataset.push_to_hub=false \
  --display_data=false \
  --play_sounds=false
```

Key parameters:

- `--robot.type=panthera_follower`: Uses the Panthera-HT Follower arm as the execution robot.
- `--teleop.type=panthera_leader`: Enables teleoperation using the Panthera-HT Leader arm.
- `--dataset.repo_id`: Local dataset ID, for example `local/panthera_demo`.
- `--dataset.num_episodes`: Number of episodes to collect.
- `--dataset.episode_time_s`: Recording duration for each episode.
- `--dataset.reset_time_s`: Reset time between episodes.

After each recording episode, the Follower arm enters position-hold mode so that the operator can manually reset the environment before starting the next episode.

### 3.2 Single-Arm Manual Teaching Mode

Use this mode when only one Panthera-HT robotic arm is available. Do not provide `--teleop.type`. The robot will enter teaching mode with gravity compensation only, allowing the operator to directly move the robotic arm to provide demonstrations.

```bash
python lerobot_record.py \
  --robot.type=panthera_follower \
  --dataset.repo_id=local/panthera_teaching_demo \
  --dataset.single_task="manual_teaching_task" \
  --dataset.num_episodes=20 \
  --dataset.episode_time_s=20 \
  --dataset.reset_time_s=60 \
  --dataset.push_to_hub=false \
  --display_data=false \
  --play_sounds=false
```

The mode selection rule is simple:

- With `--teleop.type=panthera_leader`: Leader-Follower mode.
- Without `--teleop.type`: Single-arm manual teaching mode.

## 4. Model Training

ACT example:

```bash
python lerobot_train.py \
  --dataset.repo_id=local/panthera_demo \
  --policy.type=act \
  --policy.n_obs_steps=1 \
  --policy.n_action_steps=50 \
  --policy.chunk_size=50 \
  --policy.use_vae=true \
  --policy.kl_weight=10.0 \
  --policy.optimizer_lr=1e-4 \
  --dataset.image_transforms.enable=true \
  --dataset.image_transforms.max_num_transforms=3 \
  --dataset.image_transforms.random_order=false \
  --output_dir=outputs/train/panthera_act \
  --wandb.enable=false \
  --batch_size=4 \
  --steps=50000 \
  --save_freq=10000 \
  --log_freq=100
```

Diffusion Policy example:

```bash
python lerobot_train.py \
  --dataset.repo_id=local/panthera_demo \
  --policy.type=diffusion \
  --policy.n_obs_steps=2 \
  --policy.horizon=16 \
  --policy.n_action_steps=8 \
  --output_dir=outputs/train/panthera_diffusion \
  --wandb.enable=false \
  --batch_size=4 \
  --steps=100000 \
  --save_freq=10000 \
  --log_freq=100
```

Common training parameters:

- `--policy.type`: Policy type, such as `act`, `diffusion`, or `vqbet`.
- `--batch_size`: Training batch size.
- `--steps`: Number of training steps.
- `--save_freq`: Interval between checkpoint saves.
- `--log_freq`: Interval between log outputs.
- `--wandb.enable`: Whether to enable Weights & Biases.

## 5. Policy Evaluation

Run a trained policy on the robot and record evaluation data:

```bash
python lerobot_record.py \
  --robot.type=panthera_follower \
  --policy.path=outputs/train/panthera_act/checkpoints/050000/pretrained_model \
  --dataset.repo_id=local/eval_panthera_act \
  --dataset.single_task="eval_task" \
  --dataset.num_episodes=5 \
  --dataset.episode_time_s=30 \
  --dataset.push_to_hub=false \
  --display_data=false \
  --play_sounds=false
```

## 6. Dataset Visualization

```bash
python lerobot_dataset_viz.py \
  --repo-id local/panthera_demo \
  --episode-index 0 \
  --batch-size 8 \
  --output-dir ./viz_output
```

## 7. Camera Configuration

The adapter automatically detects RealSense camera serial numbers and assigns camera names according to the following default mapping:

| Serial         | Camera Name              | Purpose            |
| -------------- | ------------------------ | ------------------ |
| `352122273105` | `right_wrist` or `wrist` | Right wrist camera |
| `352122272797` | `left_wrist`             | Left wrist camera  |
| `408322072614` | `top`                    | Top-view camera    |
| `335222076820` | `side`                   | Side-view camera   |

If your camera serial numbers are different, update the default serial numbers in:

```text
Panthera-HT_robot_lerobot/src/lerobot_robot_panthera/panthera_follower.py
```

and

```text
Panthera-HT_robot_lerobot/src/lerobot_robot_panthera/panthera_dual_follower.py
```

## 8. Outputs and Datasets

- Training outputs are typically written to `lerobot/src/lerobot/scripts/outputs/`.
- Local datasets are typically written to `Panthera-HT_lerobot_dataset/` or the default LeRobot dataset directory.
- When publishing the repository as open source, do not commit datasets, checkpoints, training logs, or large model weight files.

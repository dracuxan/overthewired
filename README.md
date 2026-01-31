# Playing OverTheWire Wargames

## About bandit.sh

This script simplifies playing the [OverTheWire Bandit wargame](https://overthewire.org/wargames/bandit/) by handling connection details and managing password storage automatically.

## How it works

The script connects to the current level using `sshpass` if the password is stored. If not, it falls back to a manual SSH connection. After each run, it asks if you've cleared the level and prompts to save the password for the next level.

## Installation

### Prerequisites

Ensure you have the following installed:

- `sshpass`
- `rsync`
- `bash`

### Quick Install

To install the script globally:

```bash
./install.sh
```

## Usage

```bash
bandit [--level <n>] [--sync] [--pull] [--version] [--help]
```

## Storage

All game data is stored in your local configuration directory: `~/.config/bandit/`.

- **Progress**: Your current level is tracked in `bandit_level.conf`.
- **Passwords**: Retrieved passwords are securely stored in the `passwords/` subdirectory (e.g., `passwords/level5`).

## Sync and Backup

The script supports syncing your progress to a remote server using `rsync`.

### 1. Configure SSH (Recommended)

Add your server to `~/.ssh/config` to enable password-less sync:

```ssh
Host my-game-server
  HostName 192.168.1.100      # Replace with your server's IP
  User myuser                 # Replace with your server username
  IdentityFile ~/.ssh/id_rsa  # Path to your private SSH key
  IdentitiesOnly yes
```

### 2. Configure Bandit

Edit `~/.config/bandit/bandit_level.conf` to point to your SSH alias:

```bash
SYNC_HOST=""    # Set this to your Host alias (e.g., 'my-game-server')
SYNC_DIR=""     # Path to remote backup directory
```

### 3. Usage

- **Push**: The script offers to sync after storing a new password. Force push with `./bandit.sh --sync`.
- **Pull**: Retrieve passwords from the server using `./bandit.sh --pull`. This updates `passwords/` without overwriting config.

## Why Sync?

I switch between devices (e.g., Laptop and Termux) sometimes and to prepare for future support of other wargames.

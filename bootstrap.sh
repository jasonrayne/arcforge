#!/usr/bin/env bash
# arcforge bootstrap script
# Bootstraps a new system with essential tools and configurations

# Exit on error
set -e

export TERM=xterm-256color
export COLORTERM=truecolor

# Log file setup
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/arcforge_install.log"

# Parse command line arguments
DRY_RUN=false
BACKUP=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --dry-run) DRY_RUN=true ;;
  --backup) BACKUP=true ;;
  --help | -h)
    echo "ArcForge Bootstrap Script"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --dry-run    Run without making actual changes"
    echo "  --backup     Backup existing configuration before changes"
    echo "  --help, -h   Display this help message"
    exit 0
    ;;
  *)
    echo "Unknown parameter: $1"
    echo "Use --help for usage information"
    exit 1
    ;;
  esac
  shift
done

# Carbonfox color palette using proper 8-bit color format
BASE_BG='\033[38;5;234m' # #161616 - Dark background
BASE_FG='\033[38;5;254m' # #f2f4f8 - Light foreground
BLUE='\033[38;5;75m'     # #78a9ff - Blue accent
PURPLE='\033[38;5;141m'  # #be95ff - Purple accent
CYAN='\033[38;5;80m'     # #33b1ff - Cyan accent
MAGENTA='\033[38;5;205m' # #ff7eb6 - Pink accent
GREEN='\033[38;5;114m'   # #25be6a - Green accent
RED='\033[38;5;203m'     # #ee5396 - Red accent
ORANGE='\033[38;5;209m'  # #ff6f00 - Orange accent
YELLOW='\033[38;5;222m'  # #fdd13a - Yellow accent
GRAY='\033[38;5;246m'    # #b6b8bb - Muted text

# Variables for hardware detection
HAS_NVIDIA=false
HAS_HYBRID_GRAPHICS=false

# Function to execute or simulate commands
execute() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${GRAY}Would execute: $*${RESET}"
    echo "[DRY RUN] Would execute: $*" >>"$LOG_FILE"
    return 0
  else
    echo "[EXEC] $*" >>"$LOG_FILE"
    "$@"
    return $?
  fi
}

# Check if running as root
check_not_root() {
  if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}${BOLD}Error: Please don't run this script as root${RESET}"
    echo -e "${GRAY}This script will use sudo when necessary for operations that require elevated privileges.${RESET}"
    echo -e "${GRAY}Running as root can cause permission issues with configuration files.${RESET}"
    exit 1
  fi
}

# Check for internet connectivity
check_internet_connection() {
  log_info "Checking internet connection..."
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would check internet connection"
    return 0
  fi

  if ! ping -c 1 github.com &>/dev/null; then
    log_error "No internet connection. This script requires internet access."
    exit 1
  fi
  log_success "Internet connection available."
}

# Backup existing configuration
backup_existing_config() {
  if [ "$BACKUP" = true ]; then
    log_info "Backing up existing configuration..."
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY RUN] Would back up existing configuration"
      return 0
    fi

    BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arcforge_backup_$(date +%Y%m%d_%H%M%S)"
    execute mkdir -p "$BACKUP_DIR"
    # Backup key dotfiles
    execute cp -r "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$BACKUP_DIR" 2>/dev/null || true
    execute cp -r "$HOME/.zshrc" "$HOME/.zprofile" "$BACKUP_DIR" 2>/dev/null || true
    execute cp -r "$HOME/.config" "$BACKUP_DIR/config" 2>/dev/null || true
    execute cp -r "$HOME/.local/share/chezmoi" "$BACKUP_DIR/chezmoi" 2>/dev/null || true
    log_success "Configuration backed up to $BACKUP_DIR"
  fi
}

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${RESET} $1"
  echo "[INFO] $1" >>"$LOG_FILE"
}
log_success() {
  echo -e "${GREEN}[SUCCESS]${RESET} $1"
  echo "[SUCCESS] $1" >>"$LOG_FILE"
}
log_warn() {
  echo -e "${YELLOW}[WARNING]${RESET} $1"
  echo "[WARNING] $1" >>"$LOG_FILE"
}
log_error() {
  echo -e "${RED}[ERROR]${RESET} $1"
  echo "[ERROR] $1" >>"$LOG_FILE"
}

# Fancy banner function
show_banner() {
  clear
  cat <<'EOF' | sed "s/^/$(echo -e "${PURPLE}${BOLD}")/g"
     _             _____                    
    / \   _ __ ___|  ___|__  _ __ __ _  ___ 
   / _ \ | '__/ __| |_ / _ \| '__/ _` |/ _ \
  / ___ \| | | (__|  _| (_) | | | (_| |  __/
 /_/   \_\_|  \___|_|  \___/|_|  \__, |\___|
                                 |___/      
EOF
  echo -e "${RESET}"
  echo -e "${MAGENTA}${BOLD}Forging your system into arcane perfection${RESET}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}${BOLD}*** DRY RUN MODE - NO CHANGES WILL BE MADE ***${RESET}"
  fi
  if [ "$BACKUP" = true ]; then
    echo -e "${CYAN}${BOLD}*** BACKUP MODE - EXISTING CONFIG WILL BE BACKED UP ***${RESET}"
  fi
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo
}

# Progress visualization
progress_bar() {
  local duration=$1
  local description=$2
  local steps=25

  # If bc is not available, use a simpler approach
  if command -v bc &>/dev/null; then
    local sleep_time=$(bc <<<"scale=2; $duration/$steps" 2>/dev/null || echo "0.1")
  else
    local sleep_time=0.1
  fi

  echo -ne "  ${description} ${BLUE}["
  for ((i = 0; i < steps; i++)); do
    echo -ne "${BLUE}▓"
    sleep "$sleep_time"
  done
  echo -e "${BLUE}] Done!${RESET}"
  echo
}

# Check for dependencies
check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    log_info "Installing $1..."
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY RUN] Would install $1"
      return 0
    fi

    case "$DISTRO" in
    "arch" | "manjaro" | "cachyos")
      execute sudo pacman -S --noconfirm "$1"
      ;;
    "ubuntu" | "pop" | "debian" | "linuxmint")
      execute sudo apt-get update && execute sudo apt-get install -y "$1"
      ;;
    "fedora")
      execute sudo dnf install -y "$1"
      ;;
    *)
      log_error "Unsupported distribution for automatic installation."
      log_info "Please install $1 manually and run this script again."
      exit 1
      ;;
    esac
    log_success "$1 installed successfully!"
  else
    log_info "$1 is already installed."
  fi
}

# Detect Linux distribution
detect_distro() {
  if [ "$DRY_RUN" = true ]; then
    DISTRO="ubuntu" # Example distro for dry run
    DISTRO_VERSION="24.04"
    log_info "[DRY RUN] Detected distribution: $DISTRO $DISTRO_VERSION"
    return 0
  fi

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_VERSION=$VERSION_ID
    log_info "Detected distribution: $DISTRO $DISTRO_VERSION"
  else
    log_error "Unable to detect Linux distribution."
    exit 1
  fi
}

# Detect NVIDIA hardware
detect_nvidia() {
  log_info "Checking for NVIDIA hardware..."
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would detect NVIDIA hardware"
    HAS_NVIDIA=true
    HAS_HYBRID_GRAPHICS=true
    return 0
  fi

  if command -v lspci &>/dev/null; then
    if lspci | grep -i nvidia &>/dev/null; then
      HAS_NVIDIA=true
      log_info "NVIDIA hardware detected."
    else
      HAS_NVIDIA=false
      log_info "No NVIDIA hardware detected."
    fi

    # Check for hybrid graphics
    if [ "$HAS_NVIDIA" = true ] && lspci | grep -i intel.*vga &>/dev/null; then
      HAS_HYBRID_GRAPHICS=true
      log_info "Hybrid graphics configuration detected (NVIDIA + Intel)."
    else
      HAS_HYBRID_GRAPHICS=false
    fi
  else
    log_warn "lspci command not found, cannot detect graphics hardware."
    check_dependency pciutils
  fi
}

# Install essential dependencies based on distribution
install_dependencies() {
  log_info "Installing essential dependencies..."

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would install essential dependencies for $DISTRO"
    return 0
  fi

  case "$DISTRO" in
  "arch" | "manjaro" | "cachyos")
    execute sudo pacman -Syu --noconfirm
    # CachyOS uses paru by default
    if [[ "$DISTRO" == "cachyos" ]]; then
      if ! command -v paru &>/dev/null; then
        execute sudo pacman -S --noconfirm paru
      fi
    fi
    check_dependency git
    check_dependency python
    check_dependency python-pip
    check_dependency openssh
    check_dependency bc
    check_dependency pciutils
    ;;
  "ubuntu" | "pop" | "debian" | "linuxmint")
    execute sudo apt-get update && execute sudo apt-get upgrade -y
    # CachyOS uses paru by default
    if [[ "$DISTRO" == "cachyos" ]]; then
      if ! command -v paru &>/dev/null; then
        execute sudo pacman -S --noconfirm paru
      fi
    fi
    check_dependency git
    check_dependency python3
    check_dependency python3-pip
    check_dependency openssh-client
    check_dependency bc
    check_dependency pciutils
    ;;
  "fedora")
    execute sudo dnf upgrade -y
    # CachyOS uses paru by default
    if [[ "$DISTRO" == "cachyos" ]]; then
      if ! command -v paru &>/dev/null; then
        execute sudo pacman -S --noconfirm paru
      fi
    fi
    check_dependency git
    check_dependency python3
    check_dependency python3-pip
    check_dependency openssh
    check_dependency bc
    check_dependency pciutils
    ;;
  *)
    log_error "Unsupported distribution: $DISTRO"
    log_info "This script supports: arch, manjaro, ubuntu, pop, debian, linuxmint, fedora"
    exit 1
    ;;
  esac

  log_success "Dependencies installed successfully!"
}

# Install Ansible
install_ansible() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would install Ansible"
    return 0
  fi

  if ! command -v ansible &>/dev/null; then
    log_info "Installing Ansible..."

    # Create virtual environment
    if ! command -v python3 &>/dev/null; then
      log_error "Python 3 is required but not installed."
      exit 1
    fi

    # Install Ansible using pip
    execute python3 -m pip install --user ansible

    if ! command -v ansible &>/dev/null; then
      # Add ~/.local/bin to PATH temporarily if needed
      PATH="$HOME/.local/bin:$PATH"
      if ! command -v ansible &>/dev/null; then
        log_error "Failed to install Ansible."
        exit 1
      fi
    fi

    log_success "Ansible installed successfully!"
  else
    log_info "Ansible is already installed."
  fi
}

# Clone the repositories
clone_repos() {
  local arcforge_repo="https://github.com/jasonrayne/arcforge.git"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would clone/update the arcforge repository"
    return 0
  fi

  if [ ! -d "${XDG_DATA_HOME:-$HOME/.local/src/personal}/arcforge" ]; then
    log_info "Cloning arcforge repository..."
    execute git clone "$arcforge_repo" "${XDG_DATA_HOME:-$HOME/.local/src/personal}/arcforge"
    log_success "Arcforge repository cloned successfully!"
  else
    log_info "Arcforge repository already exists, updating..."
    (cd "${XDG_DATA_HOME:-$HOME/.local/src/personal}/arcforge" (cd "$HOME/arcforge" && execute git pull)(cd "$HOME/arcforge" && execute git pull) execute git pull)
    log_success "Arcforge repository updated!"
  fi

  # We'll set up dotfiles later with Chezmoi, so we don't clone it directly
}

# Install Chezmoi and apply dotfiles
setup_chezmoi() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would install Chezmoi and initialize dotfiles"
    log_success "[DRY RUN] Dotfiles would be applied successfully!"
    return 0
  fi

  if ! command -v chezmoi &>/dev/null; then
    log_info "Installing Chezmoi..."
    execute sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    log_success "Chezmoi installed successfully!"
  else
    log_info "Chezmoi is already installed."
  fi

  log_info "Initializing dotfiles with Chezmoi..."
  execute chezmoi init --apply jasonrayne
  log_success "Dotfiles applied successfully!"
}

# Run Ansible playbooks
run_ansible() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would run Ansible playbooks (detecting laptop/workstation automatically)"
    log_success "[DRY RUN] Ansible playbooks would be executed successfully!"
    return 0
  fi

  log_info "Running Ansible playbooks..."

  execute cd "${XDG_DATA_HOME:-$HOME/.local/src/personal}/arcforge/ansible"

  # Determine the appropriate playbook based on hardware
  if [ -f /sys/class/power_supply/BAT0/status ] || [ -f /sys/class/power_supply/BAT1/status ]; then
    log_info "Detected a laptop system."
    PLAYBOOK="laptop.yml"
  else
    log_info "Detected a workstation system."
    PLAYBOOK="workstation.yml"
  fi

  # Run the playbook
  log_info "Executing Ansible playbook: $PLAYBOOK"
  execute ansible-playbook -K "$PLAYBOOK"

  # Run NVIDIA playbook if applicable
  if [ "$HAS_NVIDIA" = true ]; then
    log_info "Configuring NVIDIA drivers..."
    if [ "$HAS_HYBRID_GRAPHICS" = true ]; then
      execute ansible-playbook -K playbooks/nvidia_hybrid.yml
    else
      execute ansible-playbook -K playbooks/nvidia.yml
    fi
  fi

  log_success "Ansible playbooks executed successfully!"
}

# Set up optional components based on user preference
setup_optional_components() {
  echo
  echo -e "${PURPLE}${BOLD}Optional Components${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would prompt for optional components"
    log_info "[DRY RUN] Would set up development environments if selected"
    log_info "[DRY RUN] Would set up Distrobox containers if selected"
    return 0
  fi

  read -p "$(echo -e "${GRAY}Do you want to set up development environments? (y/n):${RESET} ")" -n 1 -r DEV_ENV
  echo
  if [[ $DEV_ENV =~ ^[Yy]$ ]]; then
    log_info "Setting up development environments..."
    execute cd "${XDG_DATA_HOME:-$HOME/.local/src/personal}/arcforge/ansible"
    execute ansible-playbook -K playbooks/dev_environments.yml
    log_success "Development environments set up successfully!"
  fi

  read -p "$(echo -e "${GRAY}Do you want to set up Distrobox containers? (y/n):${RESET} ")" -n 1 -r DISTROBOX
  echo
  if [[ $DISTROBOX =~ ^[Yy]$ ]]; then
    log_info "Setting up Distrobox containers..."
    execute cd "${XDG_DATA_HOME:-$HOME/.local/src/personal}/arcforge/distrobox"
    execute ./setup_containers.sh
    log_success "Distrobox containers set up successfully!"
  fi
}

# Main function
main() {
  # Set up log file
  if [ "$DRY_RUN" = true ]; then
    LOG_FILE="$HOME/arcforge_dryrun.log"
  fi

  # Touch log file
  if [ "$DRY_RUN" = true ]; then
    echo "Creating log file: $LOG_FILE"
    touch "$LOG_FILE" 2>/dev/null || echo "Could not create log file"
  else
    execute touch "$LOG_FILE"
  fi

  log_info "Beginning ArcForge installation at $(date)"

  show_banner
  check_not_root
  check_internet_connection
  backup_existing_config

  echo -e "${BOLD}Step 1:${RESET} Detecting system information..."
  detect_distro
  detect_nvidia
  progress_bar 1 "Analyzing system configuration"

  echo -e "${BOLD}Step 2:${RESET} Installing prerequisites..."
  install_dependencies
  progress_bar 2 "Installing system packages"

  echo -e "${BOLD}Step 3:${RESET} Setting up Ansible..."
  install_ansible
  progress_bar 1.5 "Configuring automation tools"

  echo -e "${BOLD}Step 4:${RESET} Cloning repositories..."
  clone_repos
  progress_bar 1 "Retrieving configurations"

  echo -e "${BOLD}Step 5:${RESET} Running Ansible playbooks..."
  run_ansible
  progress_bar 5 "Applying system configurations"

  echo -e "${BOLD}Step 6:${RESET} Setting up dotfiles with Chezmoi..."
  setup_chezmoi
  progress_bar 2 "Configuring personal environment"

  echo -e "${BOLD}Step 7:${RESET} Setting up optional components..."
  setup_optional_components
  progress_bar 2 "Finishing installation"

  log_info "Installation completed at $(date)"
  echo -e "\n${GREEN}${BOLD}✓ System successfully forged with arcane precision!${RESET}"
  echo -e "${CYAN}Your environment is now ready to use.${RESET}"
  echo -e "${BLUE}${BOLD}Please log out and log back in to apply all changes.${RESET}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}This was a dry run. No actual changes were made.${RESET}"
    echo -e "${YELLOW}Run without --dry-run to perform actual installation.${RESET}"
  fi

  echo -e "\n${GRAY}A log of this installation has been saved to: $LOG_FILE${RESET}"
}

# Execute main function
main "$@"

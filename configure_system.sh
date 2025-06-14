#!/bin/bash

set -e

if [ -z "$CURRENT_USER" ]; then
  if [ -f ./global.env ]; then
    source ./global.env
  else
    echo "Error: CURRENT_USER not set and global.env not found."
    exit 1
  fi
fi

if [ -z "$CURRENT_USER" ]; then
  echo "Error: CURRENT_USER is still not defined after sourcing global.env."
  exit 1
fi

# ===============================
#       Environment Variables
# ===============================
GRUB_FILE="/etc/default/grub"
PACMAN_FILE="/etc/pacman.conf"

# ===============================
#       GRUB Installation
# ===============================
if [ ! -d /boot/efi ]; then
  echo "Error: Directory /boot/efi not found."
  exit 1
fi

if [ ! -f /boot/efi/EFI/GRUB/grubx64.efi ]; then
  echo "Installing GRUB bootloader..."
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
else
  echo "GRUB already appears to be installed, skipping grub-install."
fi

# ===============================
#        GRUB Configuration
# ===============================
echo "Configuring GRUB to detect other operating systems..."

if [ ! -f "$GRUB_FILE" ]; then
  echo "Error: File $GRUB_FILE not found."
  exit 1
fi

if grep -q "^#*GRUB_DISABLE_OS_PROBER=" "$GRUB_FILE"; then
  sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_FILE"
else
  echo "GRUB_DISABLE_OS_PROBER=false" >>"$GRUB_FILE"
fi

grub-mkconfig -o /boot/grub/grub.cfg

# ===============================
#   Enabling Essential Services
# ===============================
echo "Enabling and starting services..."

systemctl enable pipewire pipewire-pulse wireplumber

systemctl enable NetworkManager
systemctl start NetworkManager

systemctl enable paccache.timer
systemctl enable ufw

# ===============================
#       Pacman Configuration
# ===============================
echo "Configuring pacman for parallel downloads..."

if [ ! -f "$PACMAN_FILE" ]; then
  echo "Error: File $PACMAN_FILE not found."
  exit 1
fi

if grep -q "^[#]*ParallelDownloads" "$PACMAN_FILE"; then
  sed -i 's/^[#]*ParallelDownloads.*/ParallelDownloads = 10/' "$PACMAN_FILE"
else
  sed -i '/^\[options\]/a ParallelDownloads = 10' "$PACMAN_FILE"
fi

# ===============================
#       Sudo Configuration
# ===============================
echo "Configuring sudoers file to allow wheel group..."

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# ===============================
#     Create User Directories
# ===============================
echo "Creating default user directories..."

sudo -u "$CURRENT_USER" xdg-user-dirs-update

# ===============================
#   Set ZSH as Default Shell
# ===============================
echo "Setting zsh as default shell for $CURRENT_USER..."

if ! command -v zsh >/dev/null 2>&1; then
  echo "Error: zsh not found. Install it before setting as default shell."
  exit 1
fi

chsh -s "$(which zsh)" "$CURRENT_USER"

# ===============================
#   Copy wallpaper files
# ===============================
echo "Copying wallpapers to user's home directory..."

if [ ! -d ./wallpapers ]; then
  echo "Error: Directory ./wallpapers not found."
  exit 1
fi

cp -r ./wallpapers "/home/$CURRENT_USER/"




#!/bin/bash

SYSTEMD_UNIT_DIR="/usr/lib/systemd/system/"
SYSTEMD_UNIT_USER_DIR="/usr/lib/systemd/user/"
DESKTOP_AUTOSTART_DIR="/etc/xdg/autostart/"

source config.sh
source config.sh.lib

# Install needed packages.
if [[ -z `which midori` ]]; then
  echo "Installing kiosk browser:"
  sudo apt update
  sudo apt install -y midori gnash browser-plugin-gnash icedtea-plugin
  echo "Done!"
fi
if [[ -z `which ethtool` ]]; then
  echo "Installing ethernet tools:"
  sudo apt install ethtool
  echo "Done!"
fi

# Setup ethernet interface.
ETHTOOL_UNIT_NAME="kiosk-ethtool-eth0"
if [[ -z `ls $SYSTEMD_UNIT_DIR | grep $ETHTOOL_UNIT_NAME` ]]; then
  echo -n "Copying $ETHTOOL_UNIT_NAME unit file... "
  sudo cp $ETHTOOL_UNIT_NAME.* $SYSTEMD_UNIT_DIR
  echo "Done."
fi
if [[ -z `systemctl list-unit-files | grep enabled | grep $ETHTOOL_UNIT_NAME` ]]; then
  echo "Enabling $ETHTOOL_UNIT_NAME unit:"
  sudo systemctl daemon-reload
  sudo systemctl enable $ETHTOOL_UNIT_NAME.service
  sudo systemctl start $ETHTOOL_UNIT_NAME.service
  echo "Done!"
fi

# Disable screensavers.
if [[ ! -z `which xscreensaver-command` ]]; then
  echo "Found xscreensaver. Setting up kiosk mode."
  XSCREENSAVER_UNIT_NAME="kiosk-xscreensaver"
  if [[ -z `ls $SYSTEMD_UNIT_USER_DIR | grep $XSCREENSAVER_UNIT_NAME` ]]; then
    echo -n "Copying unit files... "
    sudo cp $XSCREENSAVER_UNIT_NAME.* $SYSTEMD_UNIT_USER_DIR
    echo "Done."
  fi
  if [[ -z `systemctl --user list-timers | grep $XSCREENSAVER_UNIT_NAME` ]]; then
    echo "Enabling $XSCREENSAVER_UNIT_NAME kiosk mode timer:"
    sudo systemctl daemon-reload
    systemctl --user enable $XSCREENSAVER_UNIT_NAME.timer
    systemctl --user start $XSCREENSAVER_UNIT_NAME.timer
    echo "Done!"
  fi
fi

# Setup midori in kiosk mode.
MIDORI_DESKTOP_NAME="kiosk-midori-ws2.desktop"
if [[ ! -f "$DESKTOP_AUTOSTART_DIR$MIDORI_DESKTOP_NAME" ]]; then
  echo -n "Copying $MIDORI_DESKTOP_NAME autostart file... "
  sudo cp $MIDORI_DESKTOP_NAME $DESKTOP_AUTOSTART_DIR
  sudo sed -i s/google.com/$RPI_METEO_HOST/g "$DESKTOP_AUTOSTART_DIR$MIDORI_DESKTOP_NAME"
  echo "Done."
fi

# Setup config file params.
read -t 5 -p "Do you wish to configure the hostname with $RPI_HOSTNAME? [y] (will timeout in 5s): "
echo ""
if [ "${REPLY,,}" = "y" ]; then
  sudo raspi-config nonint do_hostname "$RPI_HOSTNAME"
  echo "Done!"
fi
read -t 5 -p "Do you wish to configure the timezone with $RPI_TIMEZONE? [y] (will timeout in 5s): "
echo ""
if [ "${REPLY,,}" = "y" ]; then
  sudo raspi-config nonint do_change_timezone "$RPI_TIMEZONE"
  echo "Done!"
fi
read -t 5 -p "Do you wish to configure the screen resolution? [y] (will timeout in 5s): "
echo ""
if [ "${REPLY,,}" = "y" ]; then
  runAsRoot do_resolution
fi
read -t 5 -p "Do you wish to configure the user password? [y] (will timeout in 5s): "
echo ""
if [ "${REPLY,,}" = "y" ]; then
  sudo echo "You will now be asked to enter a new password for the $SUDO_USER user"
  sudo passwd $SUDO_USER &&
  echo "Password changed successfully"
fi
sudo reboot

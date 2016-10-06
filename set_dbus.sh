#!/bin/sh

## This script prepares a file that can be included by other scripts in order
## to obtain the dbus session address for the current user.
## Run this at X startup, e.g. in .xinitrc

mkdir -p "${HOME}/.dbus"
touch "${HOME}/.dbus/Xdbus"
chmod 600 "${HOME}/.dbus/Xdbus"
env | grep DBUS_SESSION_BUS_ADDRESS > "${HOME}/.dbus/Xdbus"
echo 'export DBUS_SESSION_BUS_ADDRESS' >> "${HOME}/.dbus/Xdbus"

exit 0

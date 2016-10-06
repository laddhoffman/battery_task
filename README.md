# Battery Task
Run `suspend_if_low_battery.sh`from cron every minute. Needs `sudo` to execute `systemctl suspend` on low battery. Redirect stdout to /dev/null when executing from cron.
Run `set_dbus.sh` at X windows startup, e.g. in `.xnitrc`

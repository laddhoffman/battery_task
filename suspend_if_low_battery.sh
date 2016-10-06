#!/bin/bash

## ${HOME}/.dbus/Xdbus should export the variable DBUS_SESSION_BUS_ADDRESS 
## This lets us use notify-send for a logged-in user.

if [ -r "${HOME}/.dbus/Xdbus" ]; then
  . "${HOME}/.dbus/Xdbus"
fi

## TODO: use better directories, and/or make them configurable

log_file=${HOME}/suspend_log.txt
suspend_timestamp_file=${HOME}/last_suspend_time.txt
warning_timestamp_file=${HOME}/last_suspend_warning_time.txt

## TODO: make these more easily configurable

warning_threshold=20
suspend_threshold=10
warning_backoff=180
suspend_backoff=180

## Helper function to write lines to our log file as well as stdout.
## Prepends with ISO-8601 format date string, e.g. 2016-10-05T22:24:56-05:00
function log {
  echo -e "$(date -Isec) $*" | tee -a "$log_file"
}

time_since_warning=$warning_backoff
time_since_suspend=$suspend_backoff
time_since_resume=$suspend_backoff
now=$(date +%s)

if [[ -e $warning_timestamp_file ]]; then
  last_warning_unixtime=$(date +%s -d "$(cat "$warning_timestamp_file")")
  (( time_since_warning = now - last_warning_unixtime ))
fi

if [[ -e $suspend_timestamp_file ]]; then
  last_suspend_unixtime=$(date +%s -d "$(cat "$suspend_timestamp_file")")
  (( time_since_suspend = now - last_suspend_unixtime ))
fi

## This assumes you're using systemd

last_resume_time=$(journalctl --quiet --output=short-iso \
  -n 1 MESSAGE="ACPI: Low-level resume complete" | cut -d' ' -f1)
if [[ -n "$last_resume_time" ]]; then
  last_resume_unixtime=$(date +%s -d "$last_resume_time")
  (( time_since_resume = now - last_resume_unixtime ))
fi

## Use shell wildcard expansion to find our battery directory.
## Assumes only one battery.
sys_battery_dir=$(echo /sys/class/power_supply/BAT* | head -n 1)

charging_status=$(cat "$sys_battery_dir/status")
percent=$(cat "$sys_battery_dir/capacity")

is_charging=no
if [[ ${charging_status} == "Charging" ]]; then
        is_charging=yes
fi

echo "charging: $is_charging"
echo "percent: $percent"

if [[ "$is_charging" == 'yes' ]]; then
  exit
fi

if [[ "$percent" -le "$warning_threshold" ]]; then
  if (( time_since_warning < warning_backoff )); then
    log "Warned recently ($time_since_warning seconds age); Would warn, but"\
        "doing nothing at this time."
  else
    date -Isec > $warning_timestamp_file
    log "Warning, ${percent}% battery charge remaining"
    /usr/bin/notify-send -u critical -t 180000 "Low Battery" "$(acpi -b)"
  fi
fi

if [[ "$percent" -le "$suspend_threshold" ]]; then
  if (( time_since_suspend < suspend_backoff )); then
    log "Suspended recently ($time_since_suspend seconds age); Would suspend,"\
        "but doing nothing at this time."
  elif (( time_since_resume < suspend_backoff )); then
    log "Resumed recently ($time_since_resume seconds age); Would suspend,"\
        "but doing nothing at this time."
  else
    date -Isec > $suspend_timestamp_file
    #log "Would suspend, ${percent}% battery charge remaining"
    log "Suspending, ${percent}% battery charge remaining"
    sudo systemctl suspend
  fi
fi

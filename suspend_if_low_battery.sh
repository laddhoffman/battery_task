#!/bin/bash

if [ -r "$HOME/.dbus/Xdbus" ]; then
  . "$HOME/.dbus/Xdbus"
fi

log_file=${HOME}/suspend_log.txt
suspend_timestamp_file=${HOME}/last_suspend_time.txt
warning_timestamp_file=${HOME}/last_suspend_warning_time.txt
warning_threshold=20
suspend_threshold=10
warning_backoff=180
suspend_backoff=180

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

last_resume_time=$(journalctl --quiet --output=short-iso \
  -n 1 MESSAGE="ACPI: Low-level resume complete" | cut -d' ' -f1)
if [[ -n "$last_resume_time" ]]; then
  last_resume_unixtime=$(date +%s -d "$last_resume_time")
  (( time_since_resume = now - last_resume_unixtime ))
fi

status=$(acpi -b)

# Battery 0: Charging, 3%, 01:18:13 until charged

rx='^Battery 0: (\w+), ([0-9]+)%.*$'

if [[ ! "$status" =~ $rx ]]; then
        echo >&2 "no regex match"
        exit 1
fi

charging=no
if [[ ${BASH_REMATCH[1]} == "Charging" ]]; then
        charging=yes
fi
percent=${BASH_REMATCH[2]}

echo "charging: $charging"
echo "percent: $percent"

if [[ "$charging" == 'yes' ]]; then
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

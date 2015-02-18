#!/bin/bash

function handle_signal {
  PID=$!
  echo "received signal. PID is ${PID}"
  kill -s SIGHUP $PID
}

trap "handle_signal" SIGINT SIGTERM SIGHUP

echo "Changing ownership of /volumes to nobody"
chown -R nobody:nogroup /volumes
echo "starting sonarr as nobody"
chsh -s /bin/sh nobody
su - nobody -c 'mono /opt/NzbDrone/NzbDrone.exe --no-browser -data=/volumes/config/sonarr' & wait
echo "stopping sonarr"

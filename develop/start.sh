#!/bin/bash

function handle_signal {
  PID=$!
  echo "received signal. PID is ${PID}"
  kill -s SIGHUP $PID
}

trap "handle_signal" SIGINT SIGTERM SIGHUP

# Find the group IDs of all the important volumes
# Many of these gids will come from the host, so 
# ensure that the 'nobody' user belongs to all these
# gids and therefore has group-level permissions on 
# all the important volumes
#
# In some cases we will create temporary groups with
# the necessary gids so that we can add nobody to them

echo "Getting group ID's of /volumes"
MEDIA_ID=$(stat -c "%g" /volumes/media)
CONFIG_ID=$(stat -c "%g" /volumes/config)
COMPLETED_ID=$(stat -c "%g" /volumes/completed)

# Function to ensure nobody belongs to a GID. Creates 
# group if needed
GID_COUNTER=0
function add_to_group {
  ID = $1
  EXISTS=$(cat /etc/group | grep $ID | wc -l)
  
  # If doesn't exist, create new group using that GID
  # and add nobody user 
  if [ $EXISTS == "0" ]; then 
    groupadd -g $ID tempgroup-$GID_COUNTER
    usermod -a -G tempgroup-$GID_COUNTER nobody
    echo "Created group $(getent group $ID)"
    GID_COUNTER=$((GID_COUNTER + 1))
  else 
    # GID exists, find it's name and add 
    GROUP=$(getent group $ID | cut -d: -f1)
    usermod -a -G $GROUP nobody
    echo "Added nobody to $(getent group $ID)"
  fi
}

GIDS=$(printf "$MEDIA_ID\n$CONFIG_ID\n$COMPLETED_ID" | sort | uniq)
echo "Adding nobody to host GIDs: $(echo $GIDS | tr '\n' ',')"
echo $GIDS | xargs add_to_group

echo "starting sonarr as nobody"
chsh -s /bin/sh nobody
su - nobody -c 'mono /opt/NzbDrone/NzbDrone.exe --no-browser -data=/volumes/config/sonarr' & wait
echo "stopping sonarr"

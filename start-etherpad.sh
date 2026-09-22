#!/bin/bash
# cd ./etherpad-lite
#./bin/run.sh --root >> /var/log/etherpad.log 2>&1
exec node "/root/POGS_Fr/etherpad-lite/node_modules/ep_etherpad-lite/node/server.js" $* >> /var/log/etherpad.log 2>&1
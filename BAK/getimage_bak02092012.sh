#!/bin/sh

echo "1 expose 0 light $1" | nc -w 10 wavefront 3001 > /dev/null
sleep $1
# tjt increased this from 1 to 2 6-7-2011
#sleep 1
sleep 2
echo "1 readout" | nc -w 10 wavefront 3001 > /dev/null
# tjt increased this from 3 to 5 6-7-2011
#sleep 3
sleep 5
echo "1 fits 0 1322240" | nc -w 10 wavefront 3001 | tail -n +2 > $2
echo "1 idle" | nc -w 10 wavefront 3001 > /dev/null

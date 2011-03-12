#!/bin/bash
CPUPID=`ps ax | grep cpulimit | grep -v grep | awk '{print $1}'`

echo "stoping nscd daemon..."
if [ -z $CPUPID  ]; then
        /usr/sbin/nscd -K
else
        /bin/kill -9 $CPUPID
        sleep 5
        /usr/sbin/nscd -K

fi

OUT=`echo $?`

NSCDPID=`ps ax | grep /usr/sbin/nscd | grep -v grep | grep -v cpulimit| awk  '{print $1}'`

if [ $OUT -eq 0  ]; then
        echo "starting nscd daemon with cpulimit..."
        /usr/sbin/nscd
        sleep 5
        /usr/bin/cpulimit -P /usr/sbin/nscd -l 10 &
else
        /usr/sbin/nscd -K
        echo "starting nscd daemon with cpulimit..."
        /usr/sbin/nscd
        sleep 5
        /usr/bin/cpulimit -P /usr/sbin/nscd -l 10 &
fi

exit 0


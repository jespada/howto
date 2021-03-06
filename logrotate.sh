#!/bin/bash

LOGDIR=/var/log/voicemail

pushd $LOGDIR
find . -type f -mtime +21 -delete

for i in `find . -type f ! \( -iname '*.gz' \) -mtime +1| tr -d "./"`; do
	gzip $i
done

exit 0



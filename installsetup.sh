#!/bin/bash

OPENESCALAR=/opt/openescalar
AMUNC=$OPENESCALAR/amun-client

/usr/bin/env gem install stomp
mkdir -p AMUNC
cp -rp * $AMUNC
ln -s $AMUNC/bin/amun-client /etc/init.d/amun-client
/etc/init.d/amun-client setupClient

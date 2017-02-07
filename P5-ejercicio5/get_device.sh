#!/usr/bin/env bash

/bin/df --output=source $1 | /usr/bin/tail -n1 > /home/oracle/folder_device.txt

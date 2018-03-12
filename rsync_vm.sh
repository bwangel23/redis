#!/bin/bash
#
# Author: bwangel<bwangel.me@gmail.com>
# Date: 3,12,2018 13:19


rsync -av --exclude=".git/" --exclude="*.o" --exclude=".idea/" --exclude="cmake-build-debug" ./* server@192.168.56.21:~/Github/redis/

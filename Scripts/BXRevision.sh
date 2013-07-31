#!/bin/sh

#  BXRevision.sh
#  QCLUA
#
#  Created by Michael Ehrmann on 31.07.13.
#  Copyright (c) 2013 Boinx Software. All rights reserved.


SCRIPT_DIR=$(dirname $0)
GIT_DIR=$(dirname "${SCRIPT_DIR}")

REV_SHA1=`git --git-dir="${GIT_DIR}/.git" rev-list --max-count=1 HEAD`
GIT_REV=`git --git-dir="${GIT_DIR}/.git" rev-list --reverse HEAD | grep -n ${REV_SHA1} | cut -d: -f1`

echo BX_BUILD_NUMBER = $(( ${GIT_REV}+10000 )) > "${GIT_DIR}/Config/BuildNumber.xcconfig"
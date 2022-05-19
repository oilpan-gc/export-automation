#!/bin/sh

# Copyright 2020 the V8 project authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source_dir=$(cd "$(dirname "$0")"; pwd -P)

copybara_exe="java -jar $source_dir/copybara_deploy.jar"
copybara_file="$source_dir/copy.bara.sky"
copybara_flags=''

for arg in "$@"; do
  case $arg in
    --copybara-exe=*)
      copybara_exe="${arg#*=}"
      shift
      ;;
    --copybara-file=*)
      copybara_file="${arg#*=}"
      shift
      ;;
    --init-history)
      copybara_flags="$copybara_flags --init-history"
      shift
      ;;
    --force)
      copybara_flags="$copybara_flags --force"
      shift
      ;;
    *)
      echo -e "Usage:$arg"
      echo -e "    export_to_github.sh [--copybara-exe=<path-to-copybara>]\n" \
              "                       [--copybara-file=<path-to-copy.bara.sky>]\n" \
              "                       [--init-history]\n" \
              "                       [--force]"
      exit 1
  esac
done

NOCOLOR="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"

function fail {
  echo "${RED}${1}${NOCOLOR}" > /dev/stderr
  exit 1
}

function success {
  echo "${BLUE}${1}${NOCOLOR}" > /dev/stderr
  exit 0
}

function message {
  echo "${GREEN}${1}${NOCOLOR}" > /dev/stderr
}

function cleanup {
  if [ -d "$git_temp_dir" ]; then
    rm -rf $git_temp_dir
  fi
}

trap "exit 1" HUP INT PIPE QUIT TERM
trap cleanup EXIT

[ ! -f $copybara_file ] && fail "Input $copybara_file doesn't exist!"

git_temp_dir=$(mktemp -d)
if [[ ! "$git_temp_dir" || ! -d "$git_temp_dir" ]]; then
  fail "Failed to create temporary dir"
fi

message "Running copybara..."
$copybara_exe $copybara_flags $copybara_file --dry-run --git-destination-path $git_temp_dir
result=$?
if [ "$result" -eq 4 ]; then
  success "Nothing needs to be done, exiting..."
elif [ "$result" -ne 0 ]; then
  fail "Failed to run copybara"
fi

cd $git_temp_dir

chromium_trace_common_header="$git_temp_dir/src/base/chromium/trace_event_common.h"

mkdir -p $(dirname $chromium_trace_common_header)
curl "https://raw.githubusercontent.com/chromium/chromium/main/base/trace_event/common/trace_event_common.h" -SLo "$chromium_trace_common_header"

git add "$chromium_trace_common_header"
git commit --amend --no-edit --allow-empty

message "Pushing changes to GitHub..."
git push -f copybara_remote main

success "CppGC GitHub mirror was successfully updated"

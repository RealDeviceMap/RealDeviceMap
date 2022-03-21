#!/bin/bash

export NO_INSTALL_BACKTRACE=1
lldb \
  -b \
  -o "file ./RealDeviceMapApp" \
  -o "breakpoint set --file main.swift --line 9" \
  -o "run" \
  -o "process handle SIGPIPE -n true -p true -s false"
  -o "continue" \
  -o "thread backtrace" \
  -o "exit"


#!/bin/bash

export NO_INSTALL_BACKTRACE=1
lldb \
  -b \
  -o "file ./RealDeviceMapApp" \
  -o "breakpoint set --file main.swift --line 9" \
  -o "run" \
  -o "continue" \
  -o "thread backtrace" \
  -o "exit"


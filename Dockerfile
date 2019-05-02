## Base Image
FROM perfectlysoft/perfectassistant:4.1 AS base

# Perfect-COpenSSL
RUN apt-get -y update && apt-get install -y libssl-dev

# Perfect-libcurl
RUN apt-get -y update && apt-get install -y libcurl4-openssl-dev

# Perfect-mysqlclient-Linux
RUN apt-get -y update && apt-get install -y libmysqlclient-dev && sed -i -e 's/-fabi-version=2 -fno-omit-frame-pointer//g' /usr/lib/x86_64-linux-gnu/pkgconfig/mysqlclient.pc

# Perfect-LinuxBridge
RUN apt-get -y update && apt-get install -y uuid-dev && rm -rf /var/lib/apt/lists/*

# ImageMagick for creating raid images
RUN apt-get -y update && apt-get install -y imagemagick && cp /usr/bin/convert /usr/local/bin

# MySQL Client
RUN apt-get -y update && apt-get install -y mysql-client-5.7


## Build Image
FROM base AS build

WORKDIR /build
COPY Package.swift Package.swift
COPY Sources Sources
#COPY Tests Tests
#COPY resources resources
RUN swift package update
#RUN swift test -c debug
RUN swift build -c release


## Executable Image
FROM base

COPY --from=build /build/.build/release/RealDeviceMap /app/RealDeviceMap
COPY resources /app/resources
CMD cd /app/ && ./RealDeviceMap

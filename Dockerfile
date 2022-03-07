# ================================
# Build image
# ================================
FROM swift:5.4-focal as build
WORKDIR /build

# Perfect-COpenSSL
RUN apt-get -y update && apt-get install -y libssl-dev

# Perfect-libcurl
RUN apt-get -y update && apt-get install -y libcurl4-openssl-dev

# Perfect-LinuxBridge
RUN apt-get -y update && apt-get install -y uuid-dev && rm -rf /var/lib/apt/lists/*

# ImageMagick for creating raid images
RUN apt-get -y update && apt-get install -y imagemagick && cp /usr/bin/convert /usr/local/bin

# WGet
RUN apt-get -y update && apt-get install -y wget

# MySQL Client
RUN apt-get -y update && \
	apt-get install -y lsb-release mysql-client libmysqlclient-dev && \
	sed -i -e 's/-fabi-version=2 -fno-omit-frame-pointer//g' /usr/lib/x86_64-linux-gnu/pkgconfig/mysqlclient.pc

# Pre-Build
COPY Package.swift Package.swift
COPY .emptysources Sources
COPY .emptytests Tests
RUN swift package update
RUN swift build -c release -Xswiftc -g
RUN rm -rf Sources
RUN rm -rf Tests

# Build with optimizations
COPY Sources Sources
COPY Tests Tests
RUN swift build -c release -Xswiftc -g


# ================================
# Run image
# ================================
FROM swift:5.4-focal
WORKDIR /app

# Perfect-COpenSSL
RUN apt-get -y update && apt-get install -y libssl-dev

# Perfect-libcurl
RUN apt-get -y update && apt-get install -y libcurl4-openssl-dev

# Perfect-LinuxBridge
RUN apt-get -y update && apt-get install -y uuid-dev && rm -rf /var/lib/apt/lists/*

# ImageMagick for creating raid images
RUN apt-get -y update && apt-get install -y imagemagick && cp /usr/bin/convert /usr/local/bin

# WGet
RUN apt-get -y update && apt-get install -y wget

# MySQL Client
RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get -y update && \
	apt-get install -y lsb-release mysql-client libmysqlclient-dev && \
	sed -i -e 's/-fabi-version=2 -fno-omit-frame-pointer//g' /usr/lib/x86_64-linux-gnu/pkgconfig/mysqlclient.pc

# Copy build artifacts
COPY --from=build /build/.build/release .
COPY resources resources
COPY .gitsha .
COPY .gitref .

ENTRYPOINT ["./RealDeviceMapApp"]

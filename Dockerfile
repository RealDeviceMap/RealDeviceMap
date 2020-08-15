# ================================
# Build image
# ================================
FROM swift:5.2 as build
WORKDIR /build

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

# WGet
RUN apt-get -y update && apt-get install -y wget

# Pre-Build
COPY Package.swift Package.swift
RUN swift package update
COPY .emptysources Sources
COPY .emptytests Tests
RUN swift build \
    --enable-test-discovery \
    -c release \
    -Xswiftc -g
RUN rm -rf Sources
RUN rm -rf Tests

# Build with optimizations
COPY Sources Sources
COPY Tests Tests
RUN swift build \
    --enable-test-discovery \
    -c release \
    -Xswiftc -g


# ================================
# Run image
# ================================
FROM swift:5.2
WORKDIR /app

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

# WGet
RUN apt-get -y update && apt-get install -y wget

# Copy build artifacts
COPY --from=build /build/.build/release .
COPY resources resources
COPY .gitsha .
COPY .gitref .

ENTRYPOINT ["./RealDeviceMap"]

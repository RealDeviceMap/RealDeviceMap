#!/bin/bash

echo "Building build image..."
docker image build -f .jenkins/Dockerfile_build -t realdevicemap/realdevicemap-build:latest ${PWD}
echo "Building build image sucessfull"

echo "Running swift build..."
if [ "$2" = "clean" ]; then
rm -rf .build_lin/*
fi

if [ "$2" = "cleanall" ]; then
rm -rf ./.build_lin/*
rm -rf ./.packages_lin/*
fi

docker run -i -v "${PWD}:/perfectbuild" -v "${PWD}/.packages_lin:/perfectbuild/Packages" -w /perfectbuild --rm -t "realdevicemap/realdevicemap-build" swift build --build-path=/perfectbuild/.build_lin -c release

if [ $? -eq 0 ]; then
echo "Running swift build sucessfull"
else
echo "Running swift build failed"
exit -1
fi

echo "Building deploy build..."
docker image build -f .jenkins/Dockerfile_deploy -t realdevicemap/realdevicemap-beta:$1 ${PWD}
echo "Building deploy image sucessfull"

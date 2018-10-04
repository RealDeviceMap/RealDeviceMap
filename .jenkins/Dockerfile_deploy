FROM 0815flo/realdevicemap-build:latest
COPY .build_lin/release/RealDeviceMap /perfect-deployed/realdevicemap/
COPY resources /perfect-deployed/realdevicemap/resources
RUN rm -rf /var/lib/apt/lists/*
CMD cd /perfect-deployed/realdevicemap/ && ./RealDeviceMap

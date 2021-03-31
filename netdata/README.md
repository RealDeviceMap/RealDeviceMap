# Setting up Netdata integration

- move `rdm.chart.py` to the netdata python plugins directory (default: `/usr/libexec/netdata/python.d/`)
- move `rdm.config` to the netdata pythin plugin config directory (default: `/etc/netdata/python.d`)
- fill out `url`, `username` and `password` in the `rdm.config` file
- you should now see RDM stats on your netdata dashboard

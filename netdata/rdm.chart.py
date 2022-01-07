# -*- coding: utf-8 -*-
# Description: NetData module for RDM stats
# Author: 123FLO321

from bases.FrameworkServices.SimpleService import SimpleService
try:
    import urllib.request as urllib2
except ImportError:
    import urllib2
import base64
import json

priority = 90000
update_every = 15

ORDER = [
    'processing', 'devices', 'pokemon'
]

CHARTS = {
    'processing': {
        'options': [None, 'Processing Threads', 'percentage', 'processing', 'percentage', 'stacked'],
        'lines': [
            ['processing_utilization', 'utilization']
        ]
    },
    'devices': {
        'options': [None, 'Active Devices', 'devices', 'devices', 'devices', 'stacked'],
        'lines': [
            ['devices_online', 'online'],
            ['devices_offline', 'offline']
        ]
    },
    'pokemon': {
        'options': [None, 'Active Pokemon', 'pokemon', 'pokemon', 'pokemon', 'stacked'],
        'lines': [
            ['pokemon_no-iv', 'no-iv'],
            ['pokemon_iv', 'iv']
        ]
    }
}


class Service(SimpleService):
    def __init__(self, configuration=None, name=None):
        SimpleService.__init__(self, configuration=configuration, name=name)
        self.order = ORDER
        self.definitions = CHARTS
        self.url = str(self.configuration['url']) + '/api/get_data?show_status=true'
        self.username = str(self.configuration['username'])
        self.password = str(self.configuration['password'])
        self.url_opener = urllib2.build_opener()
        self.url_opener.addheaders = [
            ('Authorization', base64.b64encode(('%s:%s' % (self.username, self.password)).encode('utf-8')))
        ]

    @staticmethod
    def check():
        return True

    def get_data(self):
        data = dict()

        result = json.load(self.url_opener.open(self.url))

        data['processing_utilization'] = result['data']['status']['processing']['current'] / result['data']['status']['processing']['max'] * 100

        data['devices_online'] = result['data']['status']['devices']['online']
        data['devices_offline'] = result['data']['status']['devices']['offline']

        data['pokemon_iv'] = result['data']['status']['pokemon']['active_iv']
        data['pokemon_no-iv'] = result['data']['status']['pokemon']['active_total'] - data['pokemon_iv']

        return data

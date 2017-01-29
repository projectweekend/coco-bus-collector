from datetime import datetime
from decimal import Decimal
import os
import time

import boto3
import requests


CTA_BUS_API_KEY = os.getenv('CTA_BUS_API_KEY')
assert CTA_BUS_API_KEY

CTA_BUS_PREDICTION_ROUTE = os.getenv('CTA_BUS_PREDICTION_ROUTE')
assert CTA_BUS_PREDICTION_ROUTE

CTA_BUS_STOP_ID = os.getenv('CTA_BUS_STOP_ID')
assert CTA_BUS_STOP_ID

DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE')
assert DYNAMODB_TABLE

DYNAMOTABLE = boto3.resource('dynamodb').Table('coco_cta_bustracker')


def to_timestamp(cta_time):
    dt = datetime.strptime(cta_time, "%Y%m%d %H:%M")
    ts = time.mktime(dt.timetuple())
    return Decimal(str(ts))


def cta_bus_predictions(stop_id):
    resp = requests.get(CTA_BUS_PREDICTION_ROUTE, params={
        'stpid': stop_id,
        'key': CTA_BUS_API_KEY,
        'format': 'json'
    }).json()
    print(resp)

    bustime_resp = resp.get('bustime-response')
    if bustime_resp is None:
        raise Exception('CTA API Error: no bustime-response element')

    predictions = bustime_resp.get('prd')
    if predictions is None:
        raise Exception('CTA API Error: no bustime-response.prd element')

    for p in predictions:
        current_time = to_timestamp(p['tmstmp'])
        arrival_time = to_timestamp(p['prdtm'])
        yield {
            'stop_id': p['stpid'],
            'route_id': p['rt'],
            'route_direction': p['rtdir'],
            'vehicle_id': p['vid'],
            'current_time': current_time,
            'arrival_time': arrival_time,
            'time_until_arrival': arrival_time - current_time
        }


def lambda_handler(event, context):
    for p in cta_bus_predictions(stop_id=CTA_BUS_STOP_ID):
        DYNAMOTABLE.put_item(Item=p)


if __name__ == "__main__":
    lambda_handler(event=None, context=None)

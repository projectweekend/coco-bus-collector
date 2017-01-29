#!/usr/bin/env bash
cp requirements.txt ./deploy
cp -a ./lambda/ ./deploy/
cd deploy
pip install -r requirements.txt -t .
zip -r lambda.zip .
aws s3 cp lambda.zip s3://coco-transit-collector/lambda.zip

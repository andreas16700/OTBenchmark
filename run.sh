#!/bin/bash
docker build -t otbench .

#local:
#docker run -e PSURL=http://127.0.0.1:8081 -e SHURL=http://127.0.0.1:8082 -e OTTYPE=mono --rm otbench 1000

docker run -e PSURL=https://7610-62-228-94-47.eu.ngrok.io -e SHURL=https://7e26-62-228-94-47.eu.ngrok.io -e OTTYPE=mono --rm -it otbench 1000

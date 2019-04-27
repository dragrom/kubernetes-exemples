#!/bin/bash

if [ -z "$1" ]
then
    echo "Add path to Dockerfile. Usage: create_docker_image <path to Dockerfile> <image tag>"
elif [ -z "$2" ]
    then
        echo "Add image version. Usage: create_docker_image <path to Dockerfile> <image tag"
else    
    docker build $1 -t $2
fi

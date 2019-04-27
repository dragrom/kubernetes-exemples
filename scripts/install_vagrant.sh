#!/bin/bash

# Install vagrant on Ubuntu and CentOS

distribution=$(lsb_release -is)

if [ "$distribution" == "Ubuntu" ];
then
    # Update repositories
    sudo apt-get update

    # Install vagrant
    sudo apt-get install -y vagrant
elif [ "$distribution" == "CentOS" ];
then
    # Update repositories
    yum update -y

    # Install vagrant
    yum install -y vagrant
else
    echo "I don't knot how to install vagrant on your distribution"
fi

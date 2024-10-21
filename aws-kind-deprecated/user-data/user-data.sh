#!/bin/bash

until [ -f /home/ubuntu/startup.sh ]
do
    echo "Waiting for the file /home/ubuntu/startup.sh to be provisioned..."
    sleep 10
done

bash -x /home/ubuntu/startup.sh

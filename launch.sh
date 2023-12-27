#!/bin/bash

vagrant up
./create-client-hosts.sh
vagrant up client

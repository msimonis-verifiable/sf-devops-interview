#!/bin/bash

if [ $# -lt 1 ]
then
    echo Usage: assign_default_permsets org_alias
    exit
fi

PERMSETS="CredCheckCredentialingUser CredCheck_API_User CredCheckFacilityCredentialingUser"

for permset in $PERMSETS
do
    sf org assign permset --name $permset --target-org $1
done

#!/bin/bash
set -eu

function usage {
    echo "usage: $0 Pre-Shared-Key [Key-ID]"
    echo "  Pre-Shared-Key     The Pre-Shared-Key to set for the VPN, wrap in single quotes to set special characters"
    echo "  Key-ID (optional)  The Key-ID to use, if none is given a new key will be created"
    echo "  example: $0 'My Secure Pre-Shared-Key' 8021c3ab-06d5-4b5f-90e4-2d169392e181"
    exit 1
}

if [ "$#" -eq 0 ] || [ "$#" -gt 2 ]; then
    usage
fi

REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"

PSK=$1
KEY=$2

if [ -z $KEY ]; then 
  KEY=$(aws kms create-key --description vpn-key --region $REGION | jq -r .KeyMetadata.KeyId)
fi 

aws ssm put-parameter --name vpn.psk --value "$PSK" --type SecureString --key-id "$KEY" --region $REGION --overwrite

echo "Key-ID ${KEY}"

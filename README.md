## Cloudformation Stack for a IPSec VPN

## Files

#### README.md
This file. It describes the project and how to use it.

#### cloudformation_vpn_stack.json
The cloudformation template for the vpn stack.

#### cloudformation_parameters.json
The parameters for the VPN stack. You will need to fill these out in order to create the stack.

#### packer_centos_vpn.json
The packer configuration for the centos VPN host.

#### packer_ipsec.conf
The configuration file for the libreswan IPSec vpn server. This is baked onto the AMI during the packer provisioing process.

#### packer_provision.sh
The script used when baking the base AMI, it installs the necessary software such as libreswan and the aws-cli, creates base configurations, and performs some basic hardening.

#### set-psk.sh
A helper script to set the Pre-Shared-Key for the VPN. The first argument (required) is the pre-shared-key, to include spaces or special characters wrap it in single quotes.  
The second argument (optional) is the KMS Key-ID to use. If this is not set, a new Key will be created.  
The script will return the Key-ID used to encypt the PSK, this will need to be placed into the appropriate place in the parameters.json file.

## Usage

##### Step 1)
Modify the packer_centos_vpn.json file replacing any parameters as necessary.  
e.g the tags, ami_users, and ami name.

##### Step 2)
Validate the packer_centos_vpn.json file.  
`$ packer validate packer_centos_vpn.json`

##### Step 3)
Bake the new AMI with packer.  
```
$ packer build packer_centos_vpn.json
amazon-ebs output will be in this color.

==> amazon-ebs: Prevalidating AMI Name...
...
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs: AMIs were created:

ap-southeast-2: ami-12345678
```

##### Step 4)
Run the 'set-psk.sh' script to set the Pre-Shared-Key for the VPN.  
```
$ ./set-psk.sh 'My Secure Pre-Shared-Key'
Key-ID 8021c3ab-06d5-4b5f-90e4-2d169392e181
```

##### Step 5)
Update the cloudformation_parameters.json file as appropriate.  
Use the ami from the output of step 3, the key-id from step 4, and fill in the other parameters with the values for your environment.

##### Step 6)
Validate the stack.  
`$ aws cloudformation validate-template --template-body file://cloudformation_vpn_stack.json`

##### Step 7)
Create the stack.
```
$ aws cloudformation create-stack --stack-name ipsec-vpn-stack\
 --template-body file://cloudformation_vpn_stack.json --parameters file://cloudformation_parameters.json\
 --capabilities CAPABILITY_IAM

{
    "StackId": "arn:aws:cloudformation:ap-southeast-2:123456789123:stack/ipsec-vpn-stack/ef9872be-e7cf-48f3-a928-cd19fea70f45"
}
```

##### Step 8)
The stack will complete with two outputs.  
The first is the Elastic IP for the VPN endpoint.  
The second is the DNS name for the VPN endpoint.  
Use these to configure your VPN Client Software.

## Client configuration

#### Android

#### MacOS

#### iOS

#### Windows

#### Linux

## Tasks

#### Configuring Authentication methods
##### Using an external AD server
In the user-data (cloudformation_vpn_stack.json) or in the packer_provision.sh script configure the ec2-instance to authenticate against an AD server.
`sudo realm join -U join_account@example.com example.com --verbose`  
Details: http://docs.aws.amazon.com/directoryservice/latest/admin-guide/join_linux_instance.html

##### Using local accounts
To use local accounts, add the following to the user-data script.
`useradd -m -p encryptedPassword username`

an encrypted password can be generated with
`perl -e 'print crypt("password", "salt"),"\n"'`

##### Using in built accounts
add the usernames to ipsec.secrets (configured in packer_provision.sh)

_Note: it's recommended to store the passwords as SSM parameters and replace them at boot time rather than have raw passwords in the configuration._
```
@username1 : XAUTH "password1"
@username2 : XAUTH "password2"
```

#### Updating the Pre-Shared-Key
To update the pre-shared-key re-run the `./set-psk.sh` script with the new psk and the Key-ID. e.g.  
`$ ./set-psk.sh 'New Secure Pre-Shared-Key' 8021c3ab-06d5-4b5f-90e4-2d169392e181`
Then terminate the ec2-instance, the auto-scaling-group will create a new instance which will initialise with the new pre-shared-key on boot.

#### Viewing the IPSec logs
SSH to the instance from the IP address specified by the SSHLocation parameter.  
To see the logs since boot run `$ journalctl --boot`  
To follow the logs in realtime run `$journalctl --follow`

#### Changing the IPsec configuration
The VPN configuration is managed by the `/etc/ipsec.conf` file. This is baked onto the AMI during the packer provisioning process.  
To make changes, update this file and bake a new AMI.

Note: The /etc/ipsec.secrets file is provisioned from the provision.sh script. The contents of this file are replaced at instance boot-up from the user-data scripts.

## Todo

[ ] prove external authentication mechanism  
[ ] improve hardening (follow: https://wiki.centos.org/HowTos/OS_Protection)  

#!/bin/bash

##################
# install parity #
##################
apt update -y; apt install -y jq
bash <(curl https://get.parity.io -Lk) -r stable
parity -v
mkdir ./parity; cd ./parity

#############################
# create main account chain #
#############################

# From Master copy the result of the below command and run it here
# echo "export ADDRESS_VALIDATOR1=$ADDRESS_VALIDATOR1; export ADDRESS_VALIDATOR2=$ADDRESS_VALIDATOR2; export ADDRESS_USER=$ADDRESS_USER"
# Copy thw password file for Validator2
cat > ./chain.json <<EOL
{
    "name": "DemoPoA",
    "engine": {
        "authorityRound": {
            "params": {
                "stepDuration": "5",
                "validators" : {
                    "list": [
                      "$ADDRESS_VALIDATOR1",
                      "$ADDRESS_VALIDATOR2"
                    ]
                }
            }
        }
    },
    "params": {
        "gasLimitBoundDivisor": "0x400",
        "maximumExtraDataSize": "0x20",
        "minGasLimit": "0x1388",
        "networkID" : "0x2323"
    },
    "genesis": {
        "seal": {
            "authorityRound": {
                "step": "0x0",
                "signature": "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            }
        },
        "difficulty": "0x20000",
        "gasLimit": "0x5B8D80"
    },
    "accounts": {
        "0x0000000000000000000000000000000000000001": { "balance": "1", "builtin": { "name": "ecrecover", "pricing": { "linear": { "base": 3000, "word": 0 } } } },
        "0x0000000000000000000000000000000000000002": { "balance": "1", "builtin": { "name": "sha256", "pricing": { "linear": { "base": 60, "word": 12 } } } },
        "0x0000000000000000000000000000000000000003": { "balance": "1", "builtin": { "name": "ripemd160", "pricing": { "linear": { "base": 600, "word": 120 } } } },
        "0x0000000000000000000000000000000000000004": { "balance": "1", "builtin": { "name": "identity", "pricing": { "linear": { "base": 15, "word": 3 } } } },
        "$ADDRESS_USER": { "balance": "1000000000000000"}
  }
}
EOL


mkdir -p keys/DemoPoA
echo "Copy the file obtained from master node"
parity account import ./keys/DemoPoA/ --chain chain.json
ADDRESS_VALIDATOR2=$(parity account list --chain chain.json --keys-path keys)
########################
# parity configuration #
########################
mypublicip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
cat > ./node1.toml <<EOL
[parity]
chain = "chain.json"
base_path = "."
[network]
nat = "extip:$mypublicip"
[account]
unlock = ["$ADDRESS_VALIDATOR2"]
password = ["./.parity_password_validator2"]
[mining]
engine_signer = "$ADDRESS_VALIDATOR2"
reseal_on_txs = "none"
EOL

################
# start parity #
################
parity --config node1.toml --bootnodes enode://7a60f0f4429839b1b29ded5bff0f96e9f08e6b8ad5820f66183f0a4c60d6a9e2e89821431ee87450dddac93341875ae1ccd08bee7b2eb9fea194e6fb058d3cf3@18.197.66.225:30301 >/var/log/parity.log 2>&1 &
tail -f /var/log/parity.log


##################################################################################
# full removal of all traces of parity, associated accounts and the chain itself #
##################################################################################
apt purge -y parity
rm -rf ./.local ./parity

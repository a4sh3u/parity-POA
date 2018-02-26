#!/bin/bash

##################
# install parity #
##################
apt update -y; apt install -y jq
bash <(curl https://get.parity.io -Lk) -r stable
parity -v
mkdir ./parity; cd ./parity

#############################
# create account init chain #
#############################
cat > ./chain.json <<EOL
{
    "name": "DemoPoA",
    "engine": {
        "authorityRound": {
            "params": {
                "stepDuration": "5",
                "validators" : {
                    "list": []
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
        "0x0000000000000000000000000000000000000004": { "balance": "1", "builtin": { "name": "identity", "pricing": { "linear": { "base": 15, "word": 3 } } } }
  }
}
EOL

# parity --chain chain.json -d /tmp/parity0 --jsonrpc-apis web3,eth,net,personal,parity,parity_set,traces,rpc,parity_accounts >/var/log/parity.log 2>&1 &

##################################################################
# create an accounts (2 validator accounts and one user account) #
##################################################################
PASSWORD_VALIDATOR1=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1)
PASSWORD_VALIDATOR2=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1)
PASSWORD_USER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1)
echo $PASSWORD_VALIDATOR1 > ./.parity_password_validator1
echo $PASSWORD_VALIDATOR2 > ./.parity_password_validator2
echo $PASSWORD_USER > ./.parity_password_user

ADDRESS_VALIDATOR1=$(parity account new --chain ./chain.json --keys-path ./keys --password ./.parity_password_validator1)
ADDRESS_VALIDATOR2=$(parity account new --chain ./chain.json --keys-path ./keys --password ./.parity_password_validator2)
ADDRESS_USER=$(parity account new --chain ./chain.json --keys-path ./keys --password ./.parity_password_user)

#############################
# create main account chain #
#############################
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
    "nodes": [
		"enode://c2328c3e7857106585dbb59b712ac2ab9443d4f0b55b77451fbf33c0dda58b882f0683c4c9222cbf8d1d6893e7f926d487630810202a2c75ec6dd996dbe84715@192.168.0.12:30303"
	   ],
    "accounts": {
        "0x0000000000000000000000000000000000000001": { "balance": "1", "builtin": { "name": "ecrecover", "pricing": { "linear": { "base": 3000, "word": 0 } } } },
        "0x0000000000000000000000000000000000000002": { "balance": "1", "builtin": { "name": "sha256", "pricing": { "linear": { "base": 60, "word": 12 } } } },
        "0x0000000000000000000000000000000000000003": { "balance": "1", "builtin": { "name": "ripemd160", "pricing": { "linear": { "base": 600, "word": 120 } } } },
        "0x0000000000000000000000000000000000000004": { "balance": "1", "builtin": { "name": "identity", "pricing": { "linear": { "base": 15, "word": 3 } } } },
        "$ADDRESS_USER": { "balance": "1000000000000000"}
  }
}
EOL

########################
# parity configuration #
########################
mypublicip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
cat > ./node0.toml <<EOL
[parity]
chain = "chain.json"
base_path = "."
[network]
nat = "extip:$mypublicip"
[account]
unlock = ["$ADDRESS_VALIDATOR1"]
password = ["./.parity_password_validator1"]
[mining]
engine_signer = "$ADDRESS_VALIDATOR1"
reseal_on_txs = "none"
EOL

################
# start parity #
################
parity --config node0.toml --bootnodes enode://7a60f0f4429839b1b29ded5bff0f96e9f08e6b8ad5820f66183f0a4c60d6a9e2e89821431ee87450dddac93341875ae1ccd08bee7b2eb9fea194e6fb058d3cf3@18.197.66.225:30301 >/var/log/parity.log 2>&1 &
tail -f /var/log/parity.log
ENODE_ID=$(curl -s --data '{"jsonrpc":"2.0","method":"parity_enode","params":[],"id":0}' -H "Content-Type: application/json" -X POST localhost:8545 | awk -F '"' '{print $8}')
##########################
# export validator2 keys #
##########################
find ./keys -type f |xargs grep ${ADDRESS_VALIDATOR2:2} | awk -F ':' '{print $1}'
echo "Copy the file obtained above to the node where the second validator would be active"
echo "export ADDRESS_VALIDATOR1=$ADDRESS_VALIDATOR1; export ADDRESS_VALIDATOR2=$ADDRESS_VALIDATOR2; export ADDRESS_USER=$ADDRESS_USER"
##################################################################################
# full removal of all traces of parity, associated accounts and the chain itself #
##################################################################################
apt purge -y parity
rm -rf ./.local ./parity

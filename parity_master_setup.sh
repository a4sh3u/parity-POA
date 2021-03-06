#!/bin/bash

##################
# install parity #
##################
apt update -y; apt install -y jq
curl -kL https://get.parity.io | bash
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
[ui]
force = true
path = "./signer"
[rpc]
interface = "all"
cors = ["all"]
hosts = ["all"]
apis = ["all"]
EOL

################
# start parity #
################
parity --config node0.toml >/var/log/parity.log 2>&1 &
# tail -f /var/log/parity.log
while [ -z $ENODE_ID ]; do
  sleep 2
  ENODE_ID=$(curl -s --data '{"jsonrpc":"2.0","method":"parity_enode","params":[],"id":0}' -H "Content-Type: application/json" -X POST localhost:8545 | awk -F '"' '{print $8}')
  sleep 2
done
echo "Parity started with enode_id : $ENODE_ID"
##############################
# export validator2 settings #
##############################

echo "The Below script creates the second validator node of this parity POA network"
echo "Run the below script as it is on one of the validator node of yor choosing"
export ADDRESS_VALIDATOR1=$ADDRESS_VALIDATOR1; export ADDRESS_VALIDATOR2=$ADDRESS_VALIDATOR2; export ADDRESS_USER=$ADDRESS_USER
KEYFILE_VALIDATOR2=$(find ./keys -type f |xargs grep ${ADDRESS_VALIDATOR2:2} | awk -F ':' '{print $1}')
echo "#######################################################################################"
echo "
apt update -y; apt install -y jq
bash <(curl https://get.parity.io -Lk) -r stable
parity -v
mkdir ./parity; cd ./parity
cat > ./chain.json <<EOL
$(cat chain.json)
EOL

mkdir -p keys/DemoPoA
cat > $KEYFILE_VALIDATOR2 << EOL
$(cat $KEYFILE_VALIDATOR2)
EOL

parity account import ./keys/DemoPoA/ --chain chain.json
cat > ./.parity_password_validator2 << EOL
$(cat ./.parity_password_validator2)
EOL

cat > ./node1.toml <<EOL
[parity]
chain = \"chain.json\"
base_path = \".\"
[account]
unlock = [\"$ADDRESS_VALIDATOR2\"]
password = [\"./.parity_password_validator2\"]
[mining]
engine_signer = \"$ADDRESS_VALIDATOR2\"
reseal_on_txs = \"none\"
[ui]
force = true
path = \"./signer\"
[rpc]
interface = \"all\"
cors = [\"all\"]
hosts = [\"all\"]
apis = [\"all\"]
EOL

parity --config node1.toml --bootnodes $ENODE_ID >/var/log/parity.log 2>&1 &
"
echo "END script for second validator node"
echo "#######################################################################################"


#########################
# export user1 settings #
#########################

echo "The Below script creates the user node of this parity POA network"
KEYFILE_USER=$(find ./keys -type f |xargs grep ${ADDRESS_USER:2} | awk -F ':' '{print $1}')
echo "#######################################################################################"
echo "
apt update -y; apt install -y jq
bash <(curl https://get.parity.io -Lk) -r stable
parity -v
mkdir ./parity; cd ./parity
cat > ./chain.json <<EOL
$(cat chain.json)
EOL

mkdir -p keys/DemoPoA
cat > $KEYFILE_USER << EOL
$(cat $KEYFILE_USER)
EOL

parity account import ./keys/DemoPoA/
cat > ./.parity_password_user << EOL
$(cat ./.parity_password_user)
EOL

cat > ./node2.toml <<EOL
[parity]
chain = \"chain.json\"
base_path = \".\"
[account]
unlock = [\"$ADDRESS_USER\"]
password = [\"./.parity_password_user\"]
[ui]
force = true
path = \"./signer\"
[rpc]
interface = \"all\"
cors = [\"all\"]
hosts = [\"all\"]
apis = [\"all\"]
EOL

parity --config node2.toml --bootnodes $ENODE_ID >/var/log/parity.log 2>&1 &
"
echo "END script for user node"
echo "#######################################################################################"
##################################################################################
# full removal of all traces of parity, associated accounts and the chain itself #
##################################################################################
# apt purge -y parity
# rm -rf ./.local ./parity

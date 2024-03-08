#This is a script meant to be run to install and setup the ritual node

# Update the system and install the necessary packages
sudo apt update && sudo apt upgrade -y
sudo apt -qy install curl git jq lz4 build-essential screen -y
sudo apt install docker.io -y
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone the repository and launch the container
git clone https://github.com/Dereek69/infernet-container-starter
cd infernet-container-starter
echo "The current directory is:"
pwd

screen -S ritual-deploy-container -d -m bash -c "make deploy-container project=hello-world"

#Wait 5 seconds for the container to start
sleep 5

# Set correct variable to "No"
correct="No"

# Loop until the user wrote "Yes"
while [ "$correct" != "Yes" ]
do
    echo "Please enter your private key"
    read private_key
    echo "Please enter your rpc url"
    read rpc_url

    echo "Your private key is: $private_key"
    echo "Your rpc url is: $rpc_url"

    echo "Is this correct? (Yes/No)"
    read correct
done


#Edit the file ~/infernet-container-starter/deploy/config.json and replace:
# 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d with the user's private key
# http://host.docker.internal:8545 with the user's rpc url
# 0x5FbDB2315678afecb367f032d93F642f64180aa3 with 0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c

sed -i "s/0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d/$private_key/g" ./deploy/config.json
sed -i "s/http:\/\/host.docker.internal:8545/$rpc_url/g" ./deploy/config.json
sed -i "s/0x5FbDB2315678afecb367f032d93F642f64180aa3/0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c/g" ./deploy/config.json

# Edit the file projects/hello-world/contracts/Makefile and replace:
# 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a with the user's private key
# http://localhost:8545 with the user's rpc url

sed -i "s/0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a/$private_key/g" ./projects/hello-world/contracts/Makefile
sed -i "s/http:\/\/localhost:8545/$rpc_url/g" ./projects/hello-world/contracts/Makefile

# Edit the file projects/hello-world/contracts/script/Deploy.s.sol and replace:
# 0x5FbDB2315678afecb367f032d93F642f64180aa3 with 0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c

sed -i "s/0x5FbDB2315678afecb367f032d93F642f64180aa3/0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c/g" ./projects/hello-world/contracts/script/Deploy.s.sol

#Have the user fund the address with some ETH on base
echo "Please fund your address with some ETH on base chain"
echo "Then go here https://basescan.org/address/0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c#writeContract and click "Write" on the registerNode function"
echo "Then wait 1 hour and click "Write" on the activateNode function"
echo "Write Yes when you are done"
read done
# Loop until the user wrote "done"
while [ "$done" != "Yes" ]
do
    echo "Write Yes when you are done"
    read done
done


docker restart deploy-node-1

screen -S ritual-deploy-contracts -d -m bash -c "make deploy-contracts project=hello-world"

# Ask the user the contract called SaysHello from the output of the previous command
echo "Please enter the contract called SaysHello from the output of the previous command"
read contract

# Edit the file projects/hello-world/contracts/script/CallContract.s.sol and replace:
# 0x663F3ad617193148711d28f5334eE4Ed07016602 with the user's contract address

sed -i "s/0x663F3ad617193148711d28f5334eE4Ed07016602/$contract/g" ./infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol

screen -S ritual-call-contract -d -m bash -c "make call-contract project=hello-world"

screen -r ritual-deploy-container

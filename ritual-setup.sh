#This is a script meant to be run to install and setup the ritual node

update_and_install() {
    # Update the system and install the necessary packages
    sudo apt update
    sudo apt -qy install curl git jq lz4 build-essential screen -y
    sudo apt install docker.io -y
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}

clone_and_launch() {
    # Clone the repository and launch the container
    git clone https://github.com/Dereek69/infernet-container-starter
    cd infernet-container-starter
    screen -S ritual-deploy-container -d -m bash -c "make deploy-container project=hello-world"
    sleep 5
}

get_pk_and_rpc(){
    # Set correct variable to "No"
    correct="No"

    # Loop until the user wrote "Yes"
    while [ "$correct" != "Yes" ]
    do
        printf "\e[31mPlease enter your private key:\e[0m\n"
        read private_key
        printf "\e[31mPlease enter your rpc url:\e[0m\n"
        read rpc_url

        printf "\e[34mYour private key is: $private_key\e[0m\n"
        printf "\e[34mYour rpc url is: $rpc_url\e[0m\n"

        printf "\e[33mWrite Yes if they are correct\e[0m\n"
        read correct
    done

    #Checks if the user's private key starts with 0x, if not, it adds it
    if [ "${private_key#0x}" = "$private_key" ]; then
        private_key="0x$private_key"
    fi
}

edit_files_pk_rpc(){
    cd ~/infernet-container-starter

    #Edit the file ~/infernet-container-starter/deploy/config.json and replace:
    # 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d with the user's private key
    # http://host.docker.internal:8545 with the user's rpc url
    # 0x5FbDB2315678afecb367f032d93F642f64180aa3 with 0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c

    sed -i "s/0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d/$private_key/g" ./deploy/config.json
    sed -i "s|http://host.docker.internal:8545|$rpc_url|g" ./deploy/config.json
    sed -i "s/0x5FbDB2315678afecb367f032d93F642f64180aa3/0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c/g" ./deploy/config.json

    # Edit the file projects/hello-world/contracts/Makefile and replace:
    # 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a with the user's private key
    # http://localhost:8545 with the user's rpc url

    sed -i "s/0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a/$private_key/g" ./projects/hello-world/contracts/Makefile
    sed -i "s|http://localhost:8545|$rpc_url|g" ./projects/hello-world/contracts/Makefile

    # Edit the file projects/hello-world/contracts/script/Deploy.s.sol and replace:
    # 0x5FbDB2315678afecb367f032d93F642f64180aa3 with 0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c

    sed -i "s/0x5FbDB2315678afecb367f032d93F642f64180aa3/0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c/g" ./projects/hello-world/contracts/script/Deploy.s.sol
}

wait_for_funding(){
    #Have the user fund the address with some ETH on base
    printf "\e[34mPlease fund your address with some ETH on base chain\e[0m\n"
    printf "\e[34mThen go here https://basescan.org/address/0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c#writeContract and click \"Write\" on the registerNode function\e[0m\n"
    printf "\e[34mThen wait 1 hour and click \"Write\" on the activateNode function\e[0m\n"
    printf "\e[33mWrite Yes when you are done\e[0m\n"
    read done
    # Loop until the user wrote "done"
    while [ "$done" != "Yes" ]
    do
        printf "\e[33mWrite Yes when you are done\e[0m\n"
        read done
    done
}

install_foundry(){
    # Install foundry
    cd
    mkdir foundry
    cd foundry
    curl -L https://foundry.paradigm.xyz | bash
    . ~/.bashrc
    foundryup
    cd ~/infernet-container-starter/projects/hello-world/contracts
    forge install --no-commit foundry-rs/forge-std
    forge install --no-commit ritual-net/infernet-sdk
}

start_node(){
    cd ~/infernet-container-starter
    echo "Please wait a few seconds for the node to be activated"
    docker restart deploy-node-1
}

deploy_contract(){
    # Deploy the contract
    cd ~/infernet-container-starter
    make deploy-contracts project=hello-world
}

ask_contract(){
    #Ask the user to enter the contract address of the SaysHello contract
    printf "\e[31mPlease enter the contract called SaysHello from the output of the previous command (or from your address on basescan):\e[0m\n"
    read contract

    # Edit the file projects/hello-world/contracts/script/CallContract.s.sol and replace:
    # 0x663F3ad617193148711d28f5334eE4Ed07016602 with the user's contract address

    sed -i "s/0x663F3ad617193148711d28f5334eE4Ed07016602/$contract/g" ./projects/hello-world/contracts/script/CallContract.s.sol
}

start_helloworld(){
    cd ~/infernet-container-starter
    screen -S ritual-call-contract -d -m bash -c "make call-contract project=hello-world"
}

keep_alive(){
    # Every 5 minutes, check if the docker deploy-node-1 is running, if not, restart it
    while true
    do
        if [ "$(docker inspect -f '{{.State.Running}}' deploy-node-1)" = "false" ]; then
            printf "\e[34mThe docker deploy-node-1 is not running, restarting it\e[0m\n"
            docker restart anvil-node
            docker restart hello-world
            docker restart deploy-node-1
            docker restart deploy-fluentbit-1
            docker restart deploy-redis-1
            printf "\e[34mChecking again in 5 minutes\e[0m\n"
        # If the docker is still running, print the logs from the last 5 minutes
        else
            docker logs --since 5m deploy-node-1
        fi
        sleep 300
    done
}

option_1(){
    # Run all the functions in order
    update_and_install
    clone_and_launch
    get_pk_and_rpc
    edit_files_pk_rpc
    wait_for_funding
    install_foundry
    start_node
    deploy_contract
    ask_contract
    start_helloworld
    keep_alive
}

option_2(){
    # Run all the functions except the contract creation
    update_and_install
    clone_and_launch
    get_pk_and_rpc
    edit_files_pk_rpc
    wait_for_funding
    install_foundry
    start_node
    ask_contract
    start_helloworld
    keep_alive
}

option_3(){
    # Restart the node
    keep_alive
}

option_4(){
    # Edit the private key and rpc
    get_pk_and_rpc
    edit_files_pk_rpc
    wait_for_funding
    install_foundry
    start_node
    deploy_contract
    ask_contract
    start_helloworld
    keep_alive
}

option_5(){
    # Edit the private key and rpc
    get_pk_and_rpc
    edit_files_pk_rpc
    wait_for_funding
    install_foundry
    start_node
    ask_contract
    start_helloworld
    keep_alive
}

# Starting menu where the user can pick which part of the script to run
while true
do
    printf "\e[31mPlease select an option (default is [1]):\e[0m\n"
    printf "\e[31m[1] First time setup and complete installation\e[0m\n"
    printf "\e[31m[2] Skip the contract creation\e[0m\n"
    printf "\e[31m[3] Restart the node\e[0m\n"
    printf "\e[31m[4] Edit private key and rpc + new contract\e[0m\n"
    printf "\e[31m[5] Edit private key and rpc + skip contract\e[0m\n"
    read option

    if [ -z "$option" ]; then
        option=1
    fi

    case $option in
        1) option_1
            ;;
        2) option_2
            ;;
        3) option_3
            ;;
        4) option_4
            ;;
        5) option_5
            ;;
        *) printf "\e[31mPlease enter a valid option\e[0m\n"
            ;;
    esac
done



import { beginCell, contractAddress, toNano, TonClient4, WalletContractV4, internal, fromNano } from "@ton/ton"; // Import necessary modules from TON library
import { mnemonicToPrivateKey } from "ton-crypto"; // Import function to convert mnemonic to private key
import { buildOnchainMetadata } from "./utils/jetton-helpers"; // Import utility to build on-chain metadata

import { EmaayaJetton, storeMint } from "./output/EmaayaJetton_EmaayaJetton"; // Import jetton contract and minting function
import { JettonDefaultWallet, TokenBurn } from "./output/EmaayaJetton_JettonDefaultWallet"; // Import default wallet and token burn functions

import { printSeparator } from "./utils/print"; // Import utility to print separators
import * as dotenv from "dotenv"; // Import dotenv for environment variable management
dotenv.config(); // Load environment variables from .env file

(async () => {
    const client4 = new TonClient4({
        // endpoint: "https://sandbox-v4.tonhubapi.com",
        endpoint: "https://testnet-v4.tonhubapi.com", // Set endpoint to testnet
        // endpoint: "https://mainnet-v4.tonhubapi.com",
    });

    let mnemonics = (process.env.mnemonics_2 || "").toString(); // Retrieve mnemonics from environment variable
    let {token_name, token_uri, token_description, token_symbol, token_decimals, token_image} = process.env
    let keyPair = await mnemonicToPrivateKey(mnemonics.split(" ")); // Convert mnemonics to key pair
    let secretKey = keyPair.secretKey; // Extract secret key from key pair
    let workchain = 0; // Set workchain to basechain
    let deployer_wallet = WalletContractV4.create({ workchain, publicKey: keyPair.publicKey }); // Create deployer wallet
    console.log(deployer_wallet.address); // Log deployer wallet address

    let deployer_wallet_contract = client4.open(deployer_wallet); // Open deployer wallet contract
    const decimals = !!token_decimals ? Number(token_decimals) : 9
    const jettonParams = { // Define parameters for the jetton
        name: token_name || 'Tether USD',
        symbol: token_symbol || 'USDT',
        description: token_description || 'Tether USD',
        decimals: String(decimals),
    } as any;
    if (!!token_uri) jettonParams.uri = token_uri
    // if (!!decimals) jettonParams.dectoken_decimals = decimals
    if (!!token_image) jettonParams.image = token_image
    
    const ONE = BigInt(10 ** decimals)
    let MAX_SUPPLY = 1e9; // Set the specific total supply in nano
    // Create content Cell
    let content = buildOnchainMetadata(jettonParams); // Build on-chain metadata for the jetton
    let max_supply = ONE * BigInt(MAX_SUPPLY); // Set the specific total supply in nano

    // Compute init data for deployment
    // NOTICE: the parameters inside the init functions were the input for the contract address
    // which means any changes will change the smart contract address as well
    let init = await EmaayaJetton.init(deployer_wallet_contract.address, content, max_supply); // Initialize the jetton contract
    let jettonMaster = contractAddress(workchain, init); // Compute the contract address for the jetton master
    let deployAmount = toNano("0.15"); // Set the amount to deploy in nano

    let supply = max_supply // toNano(max_supply); // Specify total supply in nano
    let packed_msg = beginCell() // Start building a new cell for the message
        .store( // Store the minting message in the cell
            storeMint({ // Prepare the minting message
                $$type: "Mint", // Set the message type to Mint
                amount: supply, // Set the amount to mint
                receiver: deployer_wallet_contract.address, // Set the receiver to the deployer wallet address
            })
        )
        .endCell(); // End the cell construction

    // Send a message on new address contract to deploy it
    let seqno: number = await deployer_wallet_contract.getSeqno(); // Get the sequence number for the deployer wallet
    console.log("🛠️Preparing new outgoing massage from deployment wallet. \n" + deployer_wallet_contract.address); // Log the deployment wallet address
    console.log("Seqno: ", seqno + "\n"); // Log the sequence number
    printSeparator(); // Print a separator for clarity

    // Get deployment wallet balance
    let balance: bigint = await deployer_wallet_contract.getBalance(); // Retrieve the balance of the deployer wallet

    console.log("Current deployment wallet balance = ", fromNano(balance).toString(), "💎TON"); // Log the current balance in TON
    console.log("Minting:: ", MAX_SUPPLY); // Log the amount being minted
    printSeparator(); // Print a separator for clarity

    await deployer_wallet_contract.sendTransfer({ // Send a transfer message to deploy the jetton
        seqno, // Include the sequence number
        secretKey, // Include the secret key for authentication
        messages: [ // Prepare the messages to send
            internal({ // Create an internal message
                to: jettonMaster, // Set the recipient to the jetton master address
                value: deployAmount, // Set the value to deploy
                init: { // Include initialization data
                    code: init.code, // Include the contract code
                    data: init.data, // Include the contract data
                },
                body: packed_msg, // Include the packed message
            }),
        ],
    });
    console.log("====== Deployment message sent to =======\n", jettonMaster.toString({testOnly: true}));
})();
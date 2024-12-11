import "@stdlib/ownable";
import "./messages";

// ============================================================================================================ //

@interface("org.ton.jetton.master")
trait Jetton with Ownable {
    total_supply: Int; // Total supply of the Jetton tokens
    mintable: Bool; // Indicates if more tokens can be minted
    owner: Address; // Owner of the Jetton contract
    content: Cell; // Content associated with the Jetton

    receive(msg: TokenUpdateContent){ // Function to update content
        self.requireOwner(); // Allow changing content only by owner
        self.content = msg.content; // Update content
    }

    receive(msg: TokenBurnNotification){ // Function to handle token burn notifications
        self.requireSenderAsWalletOwner(msg.sender); // Check wallet
        self.total_supply = (self.total_supply - msg.amount); // Update supply

        if (msg.response_destination != null) { // Check if there is a response destination
            // Cashback
            send(SendParameters{
                    to: msg.response_destination!!, // Send to the response destination
                    value: 0, // No value sent
                    bounce: false, // Do not bounce the message
                    mode: SendRemainingValue, // Mode for sending remaining value
                    body: TokenExcesses{query_id: msg.query_id}.toCell() // Body of the message
                }
            );
        }
    }

    // https://github.com/ton-blockchain/TEPs/blob/master/text/0089-jetton-wallet-discovery.md
    receive(msg: ProvideWalletAddress){ // Function to provide wallet address
        // 0x2c76b973
        require(context().value >= ton("0.0061"), "Insufficient gas"); // Check for sufficient gas
        let init: StateInit = initOf JettonDefaultWallet(msg.owner_address, myAddress()); // Initialize wallet

        if (msg.include_address) { // Check if address should be included
            send(SendParameters{
                    to: sender(), // Send to the sender
                    value: 0, // No value sent
                    mode: SendRemainingValue, // Mode for sending remaining value
                    body: TakeWalletAddress{ // Body of the message with address
                        query_id: msg.query_id,
                        wallet_address: contractAddress(init), // Wallet address
                        owner_address: beginCell().storeBool(true).storeAddress(msg.owner_address).endCell().asSlice() // Owner address
                    }.toCell()
                }
            );
        } else {
            send(SendParameters{
                    to: sender(), // Send to the sender
                    value: 0, // No value sent
                    mode: SendRemainingValue, // Mode for sending remaining value
                    body: TakeWalletAddress{ // Body of the message without address
                        query_id: msg.query_id,
                        wallet_address: contractAddress(init), // Wallet address
                        owner_address: beginCell().storeBool(false).endCell().asSlice() // No owner address
                    }.toCell()
                }
            );
        }
    }

    // Private Methods //
    // @to The Address receive the Jetton token after minting
    // @amount The amount of Jetton token being minted
    // @response_destination The previous owner address
    fun mint(to: Address, amount: Int, response_destination: Address) { // Function to mint new tokens
        require(self.mintable, "Can't Mint Anymore"); // Check if minting is allowed
        self.total_supply = (self.total_supply + amount); // Update total supply

        let winit: StateInit = self.getJettonWalletInit(to); // Create message
        send(SendParameters{
                to: contractAddress(winit), // Send to the wallet address
                value: 0, // No value sent
                bounce: true, // Bounce the message
                mode: SendRemainingValue, // Mode for sending remaining value
                body: TokenTransferInternal{ // Body of the message for internal transfer
                    query_id: 0, // Query ID
                    amount: amount, // Amount to transfer
                    from: myAddress(), // Sender address
                    response_destination: response_destination, // Response destination
                    forward_ton_amount: 0, // No forwarded TON amount
                    forward_payload: beginCell().endCell().asSlice() // No forwarded payload
                }.toCell(),
                code: winit.code, // Code for the wallet
                data: winit.data // Data for the wallet
            }
        );
    }

    fun requireSenderAsWalletOwner(owner: Address) { // Function to check if the sender is the wallet owner
        let ctx: Context = context(); // Get the current context
        let winit: StateInit = self.getJettonWalletInit(owner); // Initialize wallet
        require(contractAddress(winit) == ctx.sender, "Invalid sender"); // Check if sender is valid
    }

    virtual fun getJettonWalletInit(address: Address): StateInit { // Function to get wallet initialization
        return initOf JettonDefaultWallet(address, myAddress()); // Return wallet initialization
    }

    // ====== Get Methods ====== //
    get fun get_jetton_data(): JettonData { // Function to get Jetton data
        return
            JettonData{
                total_supply: self.total_supply, // Total supply
                mintable: self.mintable, // Mintable status
                owner: self.owner, // Owner address
                content: self.content, // Content
                wallet_code: initOf JettonDefaultWallet(self.owner, myAddress()).code // Wallet code
            };
    }

    get fun get_wallet_address(owner: Address): Address { // Function to get wallet address
        return contractAddress(initOf JettonDefaultWallet(owner, myAddress())); // Return wallet address
    }
}

// ============================================================ //
@interface("org.ton.jetton.wallet")
contract JettonDefaultWallet {
    const minTonsForStorage: Int = ton("0.019"); // Minimum TON required for storage
    const gasConsumption: Int = ton("0.013"); // Gas consumption for operations
    balance: Int as coins = 0; // Balance of the wallet
    owner: Address; // Owner of the wallet
    master: Address; // Master address of the Jetton

    init(owner: Address, master: Address){ // Constructor for wallet initialization
        self.balance = 0; // Initialize balance to 0
        self.owner = owner; // Set owner
        self.master = master; // Set master address
    }

    receive(msg: TokenTransfer){ // Function to handle token transfers
        // 0xf8a7ea5
        let ctx: Context = context(); // Check sender
        require(ctx.sender == self.owner, "Invalid sender"); // Validate sender
        let final: Int = (((ctx.readForwardFee() * 2 + 2 * self.gasConsumption) + self.minTonsForStorage) + msg.forward_ton_amount); // Calculate final value
        require(ctx.value > final, "Invalid value"); // Check if value is valid
        
        // Update balance
        self.balance = (self.balance - msg.amount); // Deduct amount from balance
        require(self.balance >= 0, "Invalid balance"); // Ensure balance is not negative
        let init: StateInit = initOf JettonDefaultWallet(msg.sender, self.master); // Initialize wallet
        let wallet_address: Address = contractAddress(init); // Get wallet address

        send(SendParameters{
                to: wallet_address, // Send to wallet address
                value: 0, // No value sent
                mode: SendRemainingValue, // Mode for sending remaining value
                bounce: true, // Bounce the message
                body: TokenTransferInternal{ // Body of the message for internal transfer
                    query_id: msg.query_id, // Query ID
                    amount: msg.amount, // Amount to transfer
                    from: self.owner, // Sender address
                    response_destination: msg.response_destination, // Response destination
                    forward_ton_amount: msg.forward_ton_amount, // Forwarded TON amount
                    forward_payload: msg.forward_payload // Forwarded payload
                }.toCell(),
                code: init.code, // Code for the wallet
                data: init.data // Data for the wallet
            }
        );
    }

    receive(msg: TokenTransferInternal){ // Function to handle internal token transfers
        // 0x178d4519
        let ctx: Context = context(); // Get current context
        if (ctx.sender != self.master) { // Check if sender is not the master
            let sinit: StateInit = initOf JettonDefaultWallet(msg.from, self.master); // Initialize wallet
            require(contractAddress(sinit) == ctx.sender, "Invalid sender!"); // Validate sender
        }

        // Update balance
        self.balance = (self.balance + msg.amount); // Add amount to balance
        require(self.balance >= 0, "Invalid balance"); // Ensure balance is not negative

        // Get value for gas
        let msg_value: Int = self.msg_value(ctx.value); // Get message value
        let fwd_fee: Int = ctx.readForwardFee(); // Read forwarded fee

        if (msg.forward_ton_amount > 0) { // Check if there is a forwarded TON amount
            msg_value = ((msg_value - msg.forward_ton_amount) - fwd_fee); // Adjust message value
            send(SendParameters{
                    to: self.owner, // Send to the owner
                    value: msg.forward_ton_amount, // Forwarded TON amount
                    mode: SendPayGasSeparately, // Mode for sending gas separately
                    bounce: false, // Do not bounce the message
                    body: TokenNotification{ // Body of the message for notification
                        query_id: msg.query_id, // Query ID
                        amount: msg.amount, // Amount transferred
                        from: msg.from, // Sender address
                        forward_payload: msg.forward_payload // Forwarded payload
                    }.toCell()
                }
            );
        }

        // 0xd53276db -- Cashback to the original Sender
        if (msg.response_destination != null && msg_value > 0) { // Check if there is a response destination and message value is valid
            send(SendParameters{
                    to: msg.response_destination!!, // Send to the response destination
                    value: msg_value, // Message value
                    bounce: false, // Do not bounce the message
                    body: TokenExcesses{query_id: msg.query_id}.toCell(), // Body of the message for excesses
                    mode: SendPayGasSeparately // Mode for sending gas separately
                }
            );
        }
    }

    receive(msg: TokenBurn){ // Function to handle token burn
        let ctx: Context = context(); // Get current context
        require(ctx.sender == self.owner, "Invalid sender"); // Validate sender

        self.balance = (self.balance - msg.amount); // Deduct amount from balance
        require(self.balance >= 0, "Invalid balance"); // Ensure balance is not negative
        let fwd_fee: Int = ctx.readForwardFee(); // Read forwarded fee

        require(ctx.value > ((fwd_fee + 2 * self.gasConsumption) + self.minTonsForStorage), "Invalid value - Burn"); // Check if value is valid
        // Burn tokens
        send(SendParameters{
                to: self.master, // Send to the master
                value: 0, // No value sent
                mode: SendRemainingValue, // Mode for sending remaining value
                bounce: true, // Bounce the message
                body: TokenBurnNotification{ // Body of the message for burn notification
                    query_id: msg.query_id, // Query ID
                    amount: msg.amount, // Amount to burn
                    sender: self.owner, // Sender address
                    response_destination: msg.response_destination // Response destination
                }.toCell()
            }
        );
    }

    fun msg_value(value: Int): Int { // Function to calculate message value
        let msg_value: Int = value; // Initialize message value
        let ton_balance_before_msg: Int = (myBalance() - msg_value); // Calculate balance before message
        let storage_fee: Int = (self.minTonsForStorage - min(ton_balance_before_msg, self.minTonsForStorage)); // Calculate storage fee
        msg_value = (msg_value - (storage_fee + self.gasConsumption)); // Adjust message value
        return msg_value; // Return adjusted message value
    }

    bounced(msg: bounced<TokenTransferInternal>){ // Function to handle bounced internal transfers
        self.balance = (self.balance + msg.amount); // Add amount to balance
    }

    bounced(msg: bounced<TokenBurnNotification>){ // Function to handle bounced burn notifications
        self.balance = (self.balance + msg.amount); // Add amount to balance
    }

    get fun get_wallet_data(): JettonWalletData { // Function to get wallet data
        return
            JettonWalletData{
                balance: self.balance, // Wallet balance
                owner: self.owner, // Owner address
                master: self.master, // Master address
                code: initOf JettonDefaultWallet(self.owner, self.master).code // Wallet code
            };
    }
}

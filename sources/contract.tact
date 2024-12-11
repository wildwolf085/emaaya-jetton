import "./jetton";

// Message structure for Minting
message Mint {
    amount: Int; // Amount to mint
    receiver: Address; // Address to receive the minted tokens
}

contract EmaayaJetton with Jetton {
    total_supply: Int as coins; // Total supply of minted tokens
    owner: Address; // Owner of the contract
    content: Cell; // Content associated with the contract
    mintable: Bool; // Indicates if minting is allowed

    max_supply: Int as coins; // Maximum supply of tokens allowed

    // Constructor to initialize the contract
    init(owner: Address, content: Cell, max_supply: Int) {
        self.total_supply = 0; // Initialize total supply to zero
        self.owner = owner; // Set the owner of the contract
        self.mintable = true; // Allow minting initially
        self.content = content; // Set the content of the contract
        self.max_supply = max_supply; // Set the maximum supply
    }

    // Function to handle minting tokens
    receive(msg: Mint) { // 0xfc708bd2
        let ctx: Context = context(); // Get the current context
        require(ctx.sender == self.owner, "Not owner"); // Check if the sender is the owner
        require(self.mintable, "Not mintable"); // Check if minting is allowed
        require(self.total_supply + msg.amount <= self.max_supply, "Max supply exceeded"); // Check max supply
        self.mint(msg.receiver, msg.amount, self.owner); // Mint tokens to the receiver
    }

    // Function to handle public minting of a fixed amount
    receive("Mint: 100") { // Public Minting
        let ctx: Context = context(); // Get the current context
        require(self.mintable, "Not mintable"); // Check if minting is allowed
        require(self.total_supply + 100 <= self.max_supply, "Max supply exceeded"); // Check max supply
        self.mint(ctx.sender, 100, self.owner); // Mint 100 tokens to the sender
    }

    // Function to close minting by the owner
    receive("Owner: MintClose") {
        let ctx: Context = context(); // Get the current context
        require(ctx.sender == self.owner, "Not owner"); // Check if the sender is the owner
        self.mintable = false; // Set mintable to false to close minting
    }
}
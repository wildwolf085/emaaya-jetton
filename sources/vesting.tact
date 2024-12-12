import "./jetton";


/*
    0: seed
    1: private
    2: strategic
    3: KOL
    4: advisers
    5: team
    6: staking rewards
    7: airdrop / events
    8: treasury
    9: opex
    10: liquid
    */ 
    
struct VestingRecord {
    account: Address;
    value: Int as coins;
    release_time: Int; // Time when the tokens can be released
    claimed: Bool; // Indicates if the tokens have been claimed

    
}

contract EmaayaVesting {
    owner: Address; // Owner of the vesting contract
    jetton: Address; // Address of the Jetton contract
    vesting_records: map<Address, VestingRecord>; // Mapping of accounts to their vesting records

    // Constructor to initialize the vesting contract
    init(owner: Address, jetton: Address) {
        self.owner = owner;
        self.jetton = jetton;
    }

    // Function to create a new vesting record
    receive(msg: CreateVesting) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner"); // Only the owner can create vesting records

        let record = VestingRecord{
            account: msg.account,
            value: msg.value,
            release_time: msg.release_time,
            claimed: false
        };

        self.vesting_records[msg.account] = record; // Store the vesting record
    }

    // Function to claim vested tokens
    receive(msg: ClaimVestedTokens) {
        let ctx: Context = context();
        let record = self.vesting_records[ctx.sender];

        require(record.release_time <= currentTime(), "Tokens are not yet released"); // Check if tokens can be claimed
        require(!record.claimed, "Tokens already claimed"); // Check if tokens have already been claimed

        // Mint tokens to the account
        let mint_msg = Mint{
            amount: record.value,
            receiver: ctx.sender
        };

        // Call the mint function of the Jetton contract
        send(SendParameters{
            to: self.jetton,
            value: 0,
            body: mint_msg.toCell()
        });

        // Mark the record as claimed
        record.claimed = true;
        self.vesting_records[ctx.sender] = record; // Update the record
    }
}

// Messages for creating vesting and claiming tokens
message CreateVesting {
    account: Address;
    value: Int as coins;
    release_time: Int; // Time when the tokens can be released
}

message ClaimVestedTokens {}
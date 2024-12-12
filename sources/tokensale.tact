import "./jetton";
import "./vesting";

// Enum for sale stages
enum SaleStage {
    Seed,
    Private,
    Strategic,
    KOL,
    Public
}

// Struct to hold sale parameters for each stage
struct SaleParameters {
    price: Int; // Price in USDT (scaled)
    allocation: Int; // Total allocation for the stage
    cliff: Int; // Cliff period in seconds
    vesting: Int; // Vesting period in seconds
}

// Contract for Token Sale
contract TokenSale {
    owner: Address; // Owner of the contract
    current_stage: SaleStage; // Current sale stage
    sale_parameters: map<SaleStage, SaleParameters>; // Sale parameters for each stage
    total_sold: Int; // Total tokens sold
    vesting_contract: Address; // Address of the vesting contract

    // Constructor to initialize the contract
    init(owner: Address, vesting_contract: Address) {
        self.owner = owner;
        self.vesting_contract = vesting_contract;
        self.current_stage = SaleStage.Seed; // Start with Seed stage

        // Initialize sale parameters for each stage
        self.sale_parameters[SaleStage.Seed] = SaleParameters{
            price: toNano(0.016), // Price in USDT
            allocation: 32000000, // Allocation
            cliff: 3 * 30 * 24 * 60 * 60, // 3 months in seconds
            vesting: 14 * 30 * 24 * 60 * 60 // 14 months in seconds
        };
        self.sale_parameters[SaleStage.Private] = SaleParameters{
            price: toNano(0.027),
            allocation: 41000000,
            cliff: 1 * 30 * 24 * 60 * 60, // 1 month in seconds
            vesting: 8 * 30 * 24 * 60 * 60 // 8 months in seconds
        };
        self.sale_parameters[SaleStage.Strategic] = SaleParameters{
            price: toNano(0.035),
            allocation: 40000000,
            cliff: 3 * 30 * 24 * 60 * 60, // 3 months in seconds
            vesting: 12 * 30 * 24 * 60 * 60 // 12 months in seconds
        };
        self.sale_parameters[SaleStage.KOL] = SaleParameters{
            price: toNano(0.044),
            allocation: 21000000,
            cliff: 3 * 30 * 24 * 60 * 60, // 3 months in seconds
            vesting: 8 * 30 * 24 * 60 * 60 // 8 months in seconds
        };
        self.sale_parameters[SaleStage.Public] = SaleParameters{
            price: toNano(0.055),
            allocation: 20000000,
            cliff: 1 * 30 * 24 * 60 * 60, // 1 month in seconds
            vesting: 6 * 30 * 24 * 60 * 60 // 6 months in seconds
        };
    }

    // Function to purchase tokens
    receive(msg: PurchaseTokens) {
        let ctx: Context = context();
        require(ctx.value >= self.sale_parameters[self.current_stage].price, "Insufficient funds");

        let tokens_to_buy = ctx.value / self.sale_parameters[self.current_stage].price;
        require(tokens_to_buy <= self.sale_parameters[self.current_stage].allocation, "Allocation exceeded");

        // Update total sold and allocation
        self.total_sold += tokens_to_buy;
        self.sale_parameters[self.current_stage].allocation -= tokens_to_buy;

        // Create vesting record
        let vesting_msg = CreateVesting{
            account: ctx.sender,
            value: tokens_to_buy,
            release_time: currentTime() + self.sale_parameters[self.current_stage].cliff
        };
        send(vesting_contract, vesting_msg.toCell());
    }

    // Function to change the sale stage
    receive(msg: ChangeStage) {
        require(context().sender == self.owner, "Not owner");
        self.current_stage = msg.new_stage;
    }
}

// Messages for purchasing tokens and changing stages
message PurchaseTokens {
    // No additional fields needed
}

message ChangeStage {
    new_stage: SaleStage; // New stage to change to
}

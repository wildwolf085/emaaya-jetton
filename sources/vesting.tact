struct VestingRecord {
    account: Address;
    value: Int as coins;
    type: Int as uint8; 
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
}

contract EmaayaVesting {
    
    vests: map<Int, VestingRecord>;
    
}
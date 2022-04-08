pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./marko.sol";
import "./Mana.sol";

contract StakingContract is Ownable, VRFConsumerBase{

    IERC20 weth;

    bytes32 keyHash;
    uint256 fee;

    uint256 public stolenView;
    uint256 public viewRewards;

    ElfOrcToken public elfOrc;
    Mana public mana;

    // 20 $Mana per day
    uint256 public constant DAILY_MANA_RATE = 20 ether;
    
    // Minimum 1 day to unstake
    uint256 public constant MINIMUM_TO_UNSTAKE = 1 minutes;

    // Minimum 1 day to claim rewards
    uint256 public constant MINIMUM_TO_CLAIM = 1 minutes;

    // Orcs get 25% of all claimed $Mana
    uint256 public constant MANA_TAX_PERCENTAGE = 25;

    // Maximum to be earned from staking is 1.8 billion $Mana
    uint256 public constant MAXIMUM_MANA = 1800000000 ether;

    bool public paused = false;

    struct StakingElf {
        uint256 timestamp;
        address owner;
        uint256 stolen;
    }

    uint256 public totalManaRewards;
    uint256 public lastClaimedRewards;

    struct StakingOrc {
        uint256 timestamp;
        address owner;
        uint256 tax;
    }

    uint256 public manaTaxPerOrc = 0;
    uint256 public unaccountedRewards = 0;

    mapping(uint256 => StakingElf) public elfStakings;
    mapping(address => uint8) public numberOfStakedElfs;
    mapping(address => uint256[]) public elfStakingsByOwner;

    mapping(uint256 => StakingOrc) public orcStakings;
    mapping(address => uint8) public numberOfStakedOrcs;
    mapping(address => uint256[]) public orcStakingsByOwner;
    mapping(uint256 => uint256) public orcPatrolCount;

    mapping(bytes32 => uint256) patrols;

    uint256 public stakedElfCount;

    uint256 public stakedOrcCount;

    uint16 public taxPercentage = 25;
    uint16 public taxFreeminutes = 5;

    // Preimenuj patrol u ambush
    uint256 public patrolPercentage = 35;

    uint256 public patrolBasePrice = 0.000001 ether;
    
    constructor() VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255,0x326C977E6efc84E512bB9C30f76E30c160eD06FB) {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.1 * 10 ** 18; // 0.1 Link 
    }

    function stakeElf(uint256 tokenId) public update checkIfPaused{
        require(elfOrc.ownerOf(tokenId) == msg.sender, "You must own that elf");
        require(!elfOrc.isOrc(tokenId), "You can only stake elfs here");
        require(elfOrc.isApprovedForAll(msg.sender, address(this)));

        StakingElf memory staking = StakingElf(block.timestamp, msg.sender, 0);
        elfStakings[tokenId] = staking;
        elfStakingsByOwner[msg.sender].push(tokenId);
        numberOfStakedElfs[msg.sender]++;

        elfOrc.transferFrom(msg.sender, address(this), tokenId);

        stakedElfCount++;
    }

    function batchStakeElf(uint256[] memory tokenIds) external checkIfPaused{
        for (uint8 i = 0; i < tokenIds.length; i++) {
            stakeElf(tokenIds[i]);
        }
    }

    function unstakeElf(uint256 tokenId) public checkIfPaused{
        require(elfOrc.ownerOf(tokenId) == address(this), "The elf must be staked");
        StakingElf storage staking = elfStakings[tokenId];
        require(staking.owner == msg.sender, "You must own that elf");
        require(!(block.timestamp - staking.timestamp < MINIMUM_TO_UNSTAKE), "You can unstake after 1 day.");
        uint256[] storage stakedElf = elfStakingsByOwner[msg.sender];
        uint16 index = 0;
        for (; index < stakedElf.length; index++) {
            if (stakedElf[index] == tokenId) {
                break;
            }
        }
        require(index < stakedElf.length, "Elf not found");
        stakedElf[index] = stakedElf[stakedElf.length - 1];
        stakedElf.pop();
        numberOfStakedElfs[msg.sender]--;
        staking.owner = address(0);
        elfOrc.transferFrom(address(this), msg.sender, tokenId);
        stakedElfCount--;
    }

    function batchUnstakeElf(uint256[] memory tokenIds) external checkIfPaused{
        for (uint8 i = 0; i < tokenIds.length; i++) {
            unstakeElf(tokenIds[i]);
        }
    }

    function stakeOrc(uint256 tokenId) public checkIfPaused{
        require(elfOrc.ownerOf(tokenId) == msg.sender, "You must own that orc");
        require(elfOrc.isOrc(tokenId), "You can only stake orcs here");
        require(elfOrc.isApprovedForAll(msg.sender, address(this)));

        StakingOrc memory staking = StakingOrc(block.timestamp, msg.sender, manaTaxPerOrc);
        orcStakings[tokenId] = staking;
        orcStakingsByOwner[msg.sender].push(tokenId);
        numberOfStakedOrcs[msg.sender]++;

        elfOrc.transferFrom(msg.sender, address(this), tokenId);

        stakedOrcCount++;
    }

    function batchStakeOrc(uint256[] memory tokenIds) external checkIfPaused{
        for (uint8 i = 0; i < tokenIds.length; i++) {
            stakeOrc(tokenIds[i]);
        }
    }

    function unstakeOrc(uint256 tokenId) public checkIfPaused{
        require(elfOrc.ownerOf(tokenId) == address(this), "The orc must be staked");
        StakingOrc storage staking = orcStakings[tokenId];
        require(staking.owner == msg.sender, "You must own that orc");
        uint256[] storage stakedOrc = orcStakingsByOwner[msg.sender];
        uint16 index = 0;
        for (; index < stakedOrc.length; index++) {
            if (stakedOrc[index] == tokenId) {
                break;
            }
        }
        require(index < stakedOrc.length, "Orc not found");
        stakedOrc[index] = stakedOrc[stakedOrc.length - 1];
        stakedOrc.pop();
        numberOfStakedOrcs[msg.sender]--;
        staking.owner = address(0);
        elfOrc.transferFrom(address(this), msg.sender, tokenId);
        stakedOrcCount--;
    }

    function batchUnstakeOrc(uint256[] memory tokenIds) external checkIfPaused{
        for (uint8 i = 0; i < tokenIds.length; i++) {
            unstakeOrc(tokenIds[i]);
        }
    }

    function claimManyRewards(uint16[] calldata tokenIds, bool unstake) external update checkIfPaused{
        require(tx.origin == msg.sender);

        uint256 calculatedRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!checkIfIsOrc(tokenIds[i]))
                calculatedRewards += _claimElfRewards(tokenIds[i], unstake);
            else calculatedRewards += _claimOrcRewards(tokenIds[i], unstake);
        }

        if (calculatedRewards == 0) return;

        mana.mint(msg.sender, calculatedRewards);
      
    }

    function calculateReward(StakingElf memory staking) internal view returns (uint256) {
        if(totalManaRewards < MAXIMUM_MANA){
            return ((block.timestamp - staking.timestamp) * DAILY_MANA_RATE) / 1 minutes;
        }
        else if (staking.timestamp > lastClaimedRewards) {
            return 0;
        }
        else {
            return ((lastClaimedRewards - staking.timestamp) * DAILY_MANA_RATE) / 1 minutes;
        }
    }

    function _claimElfRewards(uint256 tokenId, bool unstake) internal returns (uint256 calculatedRewards) {
        StakingElf memory staking = elfStakings[tokenId];

        require(staking.owner == msg.sender, "You must be the owner of that staked elf.");
        require(!(unstake && block.timestamp - staking.timestamp < MINIMUM_TO_UNSTAKE), "You can unstake after 1 day.");
        require(!(block.timestamp - staking.timestamp < MINIMUM_TO_CLAIM), "You can claim rewards after 1 day.");

        calculatedRewards = calculateReward(staking);

        if (unstake) {
            unstakeElf(tokenId);
        } else {
            payTaxToOrcs((calculatedRewards * MANA_TAX_PERCENTAGE) / 100);

            calculatedRewards = (calculatedRewards * (100 - MANA_TAX_PERCENTAGE)) / 100 - staking.stolen;
            
            viewRewards = calculatedRewards;

            staking.stolen = 0;

            elfStakings[tokenId].timestamp = block.timestamp;
        }
    }

    function _claimOrcRewards(uint256 tokenId, bool unstake) internal returns (uint256 calculatedRewards){
        require(elfOrc.ownerOf(tokenId) == address(this), "The orc must be staked");
        
        StakingOrc memory staking = orcStakings[tokenId];

        require(staking.owner == msg.sender, "You must be the owner of that staked orc.");

        calculatedRewards = (manaTaxPerOrc - staking.tax);

        if (unstake) {
            unstakeOrc(tokenId);
        } else {
            orcStakings[tokenId].tax = manaTaxPerOrc;
            orcStakings[tokenId].timestamp = block.timestamp;
        }
    }
    
    function payTaxToOrcs(uint256 amount) internal {
        if (stakedOrcCount == 0) {
            unaccountedRewards += amount; 
            return;
        }

        manaTaxPerOrc += (amount + unaccountedRewards) / stakedOrcCount;
        unaccountedRewards = 0;
    }

    function patrolCost(uint256 tokenId) internal view returns (uint256) {
        StakingOrc storage staking = orcStakings[tokenId];
        uint256 prevTime = block.timestamp - staking.timestamp;
        uint256 exp = prevTime > 1 days ? 0 : orcPatrolCount[tokenId];
        return patrolBasePrice * (2 ** exp);
    }
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        StakingOrc storage patrolingOrc = orcStakings[patrols[requestId]];

        address orcOwner = patrolingOrc.owner;
        require(orcOwner != address(0));
        
        uint256 tokenIndex;
        uint256 elfId;
        uint256 randNum = randomness;

        do{
            randNum = uint256(keccak256(abi.encode(randNum, 7285)));
            tokenIndex = randNum % elfOrc.balanceOf(address(this));
        }
        while(elfOrc.isOrc(elfOrc.tokenOfOwnerByIndex(address(this), tokenIndex)));

        elfId = elfOrc.tokenOfOwnerByIndex(address(this), tokenIndex);
        StakingElf storage staking = elfStakings[elfId];

        uint256 rewards = calculateReward(staking);
        uint256 stealAmount = (patrolPercentage * rewards) / 100;

        staking.stolen = stealAmount;

        stolenView = stealAmount;

        if (stealAmount > 0) {
            mana.mint(orcOwner, stealAmount);
        }
    }
    
    function startPatrol(uint256 tokenId) public payable checkIfPaused{
        require(msg.value > 0, "You must pay with MATIC");
        require(elfOrc.isOrc(tokenId), "You can only patrol with orcs");
        require(elfOrc.ownerOf(tokenId) == address(this), "The orc must be staked");

        StakingOrc storage staking = orcStakings[tokenId];

        require(staking.owner == msg.sender, "You must own that orc");

        address orcOwner = elfOrc.ownerOf(tokenId);

        require(orcOwner != address(0));
        require(orcPatrolCount[tokenId] < 5, "You can patrol a maximum of 5 times per day");

        if (staking.timestamp == 0) {
            staking.timestamp = block.timestamp;
        }
        
        uint256 cost = patrolCost(tokenId);

        require(msg.value >= cost, "You must pay the correct amount of MATIC");

        if (block.timestamp - staking.timestamp > 1 days) {
            staking.timestamp = block.timestamp;
            orcPatrolCount[tokenId] = 1;
        } else {
            orcPatrolCount[tokenId]++;
        }

        bytes32 requestId = requestRandomness(keyHash, fee);
        patrols[requestId] = tokenId;
    }

    function checkIfIsOrc(uint256 tokenId) public view returns (bool){
        return elfOrc.isOrc(tokenId);
    }

    function allUnstaked(address _owner) external view returns (uint256[] memory) {
        return elfOrc.walletOfOwner(_owner);
    }

    function setMainCollection(address collection) external onlyOwner{
        elfOrc = ElfOrcToken(collection);
    }

    function setRewardCollection(address collection) external onlyOwner{
        mana = Mana(collection);
    }

    function setWETH(address collection) external onlyOwner{
        weth = IERC20(collection);
    }

    function withdraw_MATIC(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    function balance_MATIC() external onlyOwner view returns(uint256){
        return address(this).balance;
    }

    function withdraw_WETH(uint256 amount) external onlyOwner{
        weth.transfer(owner(),amount);
    }

    function balance_WETH() external onlyOwner view returns(uint256){
        return weth.balanceOf(address(this));
    }

    function togglePause() external onlyOwner{
        paused = !paused;
    }

    modifier update() {
        if (totalManaRewards < MAXIMUM_MANA){
            totalManaRewards = totalManaRewards + ((block.timestamp - lastClaimedRewards) * stakedElfCount * DAILY_MANA_RATE) / 1 minutes;
            lastClaimedRewards = block.timestamp;
        }
        _;
    }

    modifier checkIfPaused() {
        require(!paused, "Contract paused");
        _;
    }
}
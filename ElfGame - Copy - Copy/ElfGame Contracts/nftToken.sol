pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Mana.sol";

contract ElfOrcToken is ERC721Enumerable, Ownable, VRFConsumerBase{

    ERC20 weth;

    uint256 mintEthCostPresale = 0.015 ether;
    uint256 mintEthCostMainSale = 0.03 ether;
    uint256 mintEthCost;

    bytes32 public keyHash;
    uint256 public fee;

    uint256 public constant MAX_TOKENS = 12200;
    uint256 public constant PUBLIC_SALE_TOKENS = 4000;
    uint256 public constant FREE_TOKENS = 1200;

    uint256 public minted;

    string orcURI = "https://ipfs.io/ipfs/QmcuAQLUyeQpE8TW6JETjS7X6KTNWfyFEcQgfo9QLaefxH/";
    string elfURI = "https://ipfs.io/ipfs/QmYoUQNMKnJM5QJr4pME4LJj4VKnaqicm5ebpzzjKoJb1s/";
    
    IERC721Enumerable public invitationCollection;
    Mana public mana;

    mapping(uint256=>bool) public isOrc;

    uint256[] public orcs;
    uint256 public elfCount;

    uint256 public stolenMints;

    struct TokenInfo {
        address minter;
        uint256 tokenId;
        bool fulfilled;
    }

    mapping(uint256=>uint256) private dataId;
    mapping(uint256=>bool) private takenDataOrcs;
    mapping(uint256=>bool) private takenDataElfs;
    
    mapping(address=>uint256) public publicSoldForWallet;
    mapping(bytes32=>TokenInfo) tokensMintedInfo;

    bool public isPresale = false;
    bool public paused = false;

    constructor(address _mana) ERC721("ElfOrc", "EO") VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255,0x326C977E6efc84E512bB9C30f76E30c160eD06FB) {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.1 * 10 ** 18; // 0.1 Link 
        mana = Mana(_mana);
        mintEthCost = mintEthCostPresale;
    }

    function setType(uint256 tokenId, uint256 seed) internal {
        uint256 randomNum = uint256(keccak256(abi.encode(seed, 3258))) % 10;
        if (randomNum == 5) {
            isOrc[tokenId] = true;
            orcs.push(tokenId);
        }
        else{
            elfCount++;
        }
    }

    function setData(uint256 tokenId, uint256 seed) internal {
        uint256 randNum = seed;
        uint256 data;
        uint256 maxCombinations = isOrc[tokenId] ? 10 : 10;

        do{
            randNum = uint256(keccak256(abi.encode(randNum, 8219)));
            data = randNum % maxCombinations + 1;
        }
        while(isOrc[tokenId] ? takenDataOrcs[data] : takenDataElfs[data]);

        if(isOrc[tokenId]){
            takenDataOrcs[data] = true;
        }
        else{
            takenDataElfs[data] = true;
        }

        dataId[tokenId] = data;
    }

    function getReceiver(uint256 tokenId, address ogMinter, uint256 seed) internal view returns (address) {
        // Random owner samo za stake-ovane orkove
        if (/*tokenId > FREE_TOKENS + PUBLIC_SALE_TOKENS && tokenId <= MAX_TOKENS && */(uint256(keccak256(abi.encode(seed, 5312))) % 10) == 5) {
            uint256 orc = orcs[uint256(keccak256(abi.encode(seed, 7943))) % orcs.length];
            address newOwner = ownerOf(orc);
            if (newOwner != address(0)) {
                return newOwner;
            }
        }
        return ogMinter;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override{
        TokenInfo storage token = tokensMintedInfo[requestId];
        require(token.minter != address(0));

        setType(token.tokenId, randomness);
        setData(token.tokenId, randomness);
        address receiver = getReceiver(token.tokenId, token.minter, randomness);

        if (receiver != token.minter) {
            stolenMints++;
        }

        _safeMint(receiver, token.tokenId);

        token.fulfilled = true;
    }

    function publicSale(uint16 amount) external checkIfPaused{
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK tokens on contract.");

        address tokenMinter = _msgSender();

        require(tx.origin == tokenMinter, "Contracts are not allowed to mint.");
        //require(minted >= FREE_TOKENS,"You can mint only after airdrop.");
        require(minted + amount <= FREE_TOKENS + PUBLIC_SALE_TOKENS, "Public sale over");
        require(amount > 0 && amount <= 10, "Maximum of 10 mints per transaction.");
        require(publicSoldForWallet[tokenMinter] + amount <= 50, "You can't mint more than 50 per wallet.");

        if(isPresale){
            require(invitationCollection.balanceOf(msg.sender) > 0, "Minter does not own at least one invitation token.");
        }

        uint256 price = amount * mintEthCost;

        require(weth.allowance(msg.sender,address(this)) >= price && weth.balanceOf(msg.sender) >= price, "You must pay the correct amount of ETH.");
        require(weth.transferFrom(msg.sender, address(this), price));

        for (uint16 i; i < amount; i++) {
            minted++;
            publicSoldForWallet[tokenMinter]++;
            bytes32 requestId = requestRandomness(keyHash, fee);
            tokensMintedInfo[requestId] = TokenInfo(msg.sender, minted, false);
        }
    }

    function manaPrice(uint16 amount) internal view returns (uint256) {
        uint256 boughtTokens = minted + amount - FREE_TOKENS;
        // Da moze da se menja sa koliko se mnozi (ovaj 40)
        return (boughtTokens / 500 + 1) * 40 ether;
    }

    function buyWithMana(uint16 amount) external checkIfPaused{
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK tokens on contract.");

        address tokenMinter = _msgSender();

        require(tx.origin == tokenMinter, "Contracts are not allowed to mint.");
        require(minted + amount <= MAX_TOKENS, "All available NFT's have beem sold out.");
        require(amount > 0 && amount <= 10, "Maximum of 10 mints per transaction.");

        // Dodaj bool pause za ovo ispod
        //require(minted >= FREE_TOKENS + PUBLIC_SALE_TOKENS ,"You can mint with mana only after presale/mainsale.");

        //uint256 price = amount * manaPrice(amount);

        uint256 price = amount * 100 ether;

        require(mana.allowance(tokenMinter, address(this)) >= price && mana.balanceOf(tokenMinter) >= price, "You need to send enough mana.");
        require(mana.transferFrom(tokenMinter, address(this), price));

        mana.burn(address(this),price);

        for (uint16 i; i < amount; i++) {
            minted++;
            bytes32 requestId = requestRandomness(keyHash, fee);
            tokensMintedInfo[requestId] = TokenInfo(tokenMinter, minted, false);
        }
    }

    function airdrop(address[] memory _wallets) external onlyOwner checkIfPaused{
        require(LINK.balanceOf(address(this)) >= fee * _wallets.length, "Not enough LINK tokens on contract.");

        for(uint256 i; i < _wallets.length; i++){
            minted++;
            bytes32 requestId = requestRandomness(keyHash, fee);
            tokensMintedInfo[requestId] = TokenInfo(_wallets[i], minted, false);
        }
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory){
        uint256 tokensOwned = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](tokensOwned);
        for (uint256 i; i < tokensOwned; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function orcCount() public view returns (uint256) {
        return orcs.length;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token.");
        if(isOrc[tokenId]){
            return bytes(orcURI).length > 0 ? string(abi.encodePacked(orcURI,Strings.toString(dataId[tokenId]),".json")): "";
        }
        else{
            return bytes(elfURI).length > 0 ? string(abi.encodePacked(elfURI,Strings.toString(dataId[tokenId]),".json")): "";
        }
    }

    function setInvitationCollection(address collection) external onlyOwner{
        invitationCollection = IERC721Enumerable(collection);
    }

    function setRewardCollection(address collection) external onlyOwner{
        mana = Mana(collection);
    }

    function setOrcURI(string memory _uri) external onlyOwner {
        orcURI = _uri;
    }

    function setElfURI(string memory _uri) external onlyOwner {
        elfURI = _uri;
    }

    function balance_WETH() external onlyOwner view returns(uint256){
        return weth.balanceOf(address(this));
    }

    function withdraw_WETH(uint256 amount) external onlyOwner{
        weth.transfer(owner(),amount);
    }

    function togglePresale() external onlyOwner{
        if(isPresale){
            isPresale = !isPresale;
            mintEthCost = mintEthCostMainSale;
        }
        else{
            isPresale = !isPresale;
            mintEthCost = mintEthCostPresale;
        }
    }

    function togglePause() external onlyOwner{
        paused = !paused;
    }

    modifier checkIfPaused(){
        require(!paused,"Contract paused!");
        _;
    }
}

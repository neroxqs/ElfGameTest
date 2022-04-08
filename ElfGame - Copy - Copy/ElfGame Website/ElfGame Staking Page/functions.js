// Global variables

var stakingTimestamp = new Map();

var stakedElfsInfo = new Map();
var stakedOrcsInfo = new Map();

var idToURI = new Map();
var idToImage = new Map();

var stakedElfsArray;
var stakedOrcsArray;

var unstakedElfsArray;
var unstakedOrcsArray;

// JSON functions

async function getContractsJSON() {
  const response = await fetch("./contract_info/contracts.json");
  const json = await response.json();
  return json;
}

async function getImageNFT(){
  /*
  var allIds = stakedElfsArray.concat(unstakedElfsArray,stakedOrcsArray,unstakedOrcsArray);
  var response;
  var json;

  allIds.forEach(async function(id){
    response = await fetch(idToURI.get(id));
    json = await response.json();

    idToImage.set(id,json.image);
  });
  */
}

// Time format functions

function time(ms) {
  var d, h, m, s;
  if (isNaN(ms)) {
      return {};
  }
  d = ms / (1000 * 60 * 60 * 24);
  h = (d - ~~d) * 24;
  m = (h - ~~h) * 60;
  s = (m - ~~m) * 60;
  return {d: ~~d, h: ~~h, m: ~~m, s: ~~s};
}

function toFormatString(tStruct){
  var res = '';
  if (typeof tStruct === 'object'){
      res += tStruct.d + ':'+ ((tStruct.h<10) ? ('0'+tStruct.h):(tStruct.h)) + ':' + ((tStruct.m<10) ? ('0'+tStruct.m):(tStruct.m)) + ':' + ((tStruct.s<10) ? ('0'+tStruct.s):(tStruct.s));
  }
  return res;
}

// Connect

async function checkNetwork(params) {
  web3.eth.net.getId().then((networkId) => {
    if (networkId != 137) {
      alert("Connect to matic mainnet first.");
      window.location.href = "../ElfGame Homepage/index.html";
    }
  })
  .catch((err) => {
    alert("Unable to retrieve netwok information.");
  });
}

async function connect() {
  //checkNetwork();
  const accounts = await getAccounts();

  if(accounts.length>0){
    updateAccounts(accounts[0]);
  }
  else{
    window.location.href = "../ElfGame Homepage/index.html"
  }
}

// Loading web3

async function loadWeb3() {
  if (window.ethereum) {
      window.web3 = new Web3(window.ethereum);

      connect()
  }
  else{
    web3.eth.net.getId().then(console.log);
    web3.eth.net.getNetworkType().then(console.log);
    alert("You don't have metamask.");
    window.location.href = "../ElfGame Homepage/index.html";
  }
}

// Getting contracts

async function loadStakingContract() {
  var json = await getContractsJSON();
  return await new window.web3.eth.Contract(json.stakeContractABI, json.stakeContractAddress);
}

async function loadMintingContract() {
  var json = await getContractsJSON();
  return await new web3.eth.Contract(json.mintContractABI, json.mintContractAddress);
}

async function loadManaContract() {
  var json = await getContractsJSON();
  return await new web3.eth.Contract(json.manaContractABI, json.manaContractAddress);
}

async function loadWethContract() {
  /*
  var json = await getContractsJSON();
  return await new web3.eth.Contract(json.wethContractABI, json.wethContractAddress);
  */
}

// Update elements

async function updateMana() {
  const manaBalance = document.getElementById('manaBalance');

  const accounts = await getAccounts();
  var amount = await window.manaContract.methods.balanceOf(accounts[0]).call();
  amount = amount/(10**18)

  manaBalance.innerHTML = "$MANA Balance amount: " + amount.toFixed(2);
}

async function updateTotalElfRewards(rewards){
  const totalRewards = document.getElementById('totalElfMana');
  totalRewards.innerHTML = "Total $MANA collected by elfs: " + rewards; 
}

async function updateTotalStakedElfs() {
  const totalStakedElfs = document.getElementById('totalStakedElfs');

  const accounts = await getAccounts();
  var number = await window.stakeContract.methods.numberOfStakedElfs(accounts[0]).call();

  totalStakedElfs.innerHTML = "Total elf staked: " + number;
}

async function updateAccounts(address) {
  const wallet = document.getElementById('walletAddress');
  wallet.innerHTML = "Your address  : " + address;
}

// User Accounts

async function getAccounts(){
  return await ethereum.request({ method: 'eth_accounts' });
}

// Count up values

async function counter() {
  var allStakedIds = stakedElfsArray.concat(stakedOrcsArray);

  async function cycle(){
    allStakedIds.forEach(function(id) {
      var stakeDate = stakingTimestamp.get(id);
      var currentDate = new Date();
      var newDate = new Date(Math.abs(currentDate-stakeDate));

      var timeParagraph = document.getElementById('counter' + id);
      timeParagraph.innerHTML = toFormatString(time(newDate));
    });
    
    setTimeout(cycle, 1000);
  }

  cycle();
}

async function rewards() {
  var minute = 60000;
  var totalMana;
  var manaTaxPerOrc;

  async function cycle(){
    totalMana = 0;
    manaTaxPerOrc = await window.stakeContract.methods.manaTaxPerOrc().call()

    stakedElfsArray.forEach(function(id){
      var stakeDate = stakingTimestamp.get(id);
      var currentDate = new Date();
      var elfReward = (Math.abs(currentDate-stakeDate) * 25) / minute;
      var rewardAmount = document.getElementById('rewardTokensAmount'+id);

      //var reward = await window.stakeContract.methods.calculateReward(elf).call();
      //reward = reward - elf.stolen;

      totalMana += elfReward;

      rewardAmount.innerHTML = elfReward.toFixed(2);
    });

    stakedOrcsArray.forEach(function(id){
      var rewardAmount = document.getElementById('rewardTokensAmount'+id);
      var orc = stakedOrcsInfo.get(id)
      var reward = (manaTaxPerOrc - orc.tax)/(10**18);

      rewardAmount.innerHTML = reward.toFixed(2);
    });
    
    updateTotalElfRewards(totalMana.toFixed(2)); 
    setTimeout(cycle, minute);
  }

  cycle();

  /*
  async function cycle(){
    totalMana = 0;
    manaTaxPerOrc = await window.stakeContract.methods.manaTaxPerOrc().call()

    stakedElfsArray.forEach(function(id){
      var elf = stakedElfsInfo.get(id);
      var rewardElf = await window.stakeContract.methods.calculateReward(elf).call();

      var rewardAmountElf = document.getElementById('rewardTokensAmount'+id);
      
      rewardElf = rewardElf - elf.stolen;

      totalMana += rewardElf;

      rewardAmountElf.innerHTML = rewardElf.toFixed(2);
    });

    stakedOrcsArray.forEach(function(id){
      var rewardAmountOrc = document.getElementById('rewardTokensAmount'+id);
      var orc = stakedOrcsInfo.get(id)
      var rewardOrc = (manaTaxPerOrc - orc.tax)/(10**18);

      rewardAmountOrc.innerHTML = reward.toFixed(2);
    });
    
    updateTotalElfRewards(totalMana.toFixed(2)); 
    setTimeout(cycle, minute);
  }

  cycle();
  */
}

// Loading tokens to variables

async function loadStakedElfs(){
  var id;
  var tokenInfo;
  var uri;
  stakedElfsArray = new Array();

  const accounts = await getAccounts();
  const lengthElfs = await window.stakeContract.methods.numberOfStakedElfs(accounts[0]).call();

  for (let i = 0; i < lengthElfs; i++) {
    id = await window.stakeContract.methods.elfStakingsByOwner(accounts[0],i).call();
    tokenInfo = await window.stakeContract.methods.elfStakings(id).call();
    uri = await window.mintContract.methods.tokenURI(id).call();

    stakedElfsArray.push(id);
    stakingTimestamp.set(id ,new Date(tokenInfo.timestamp*1000));
    stakedElfsInfo.set(id, tokenInfo);
    idToURI.set(id, uri);
  }
}

async function loadStakedOrcs(){
  var id;
  var tokenInfo;
  var uri;
  stakedOrcsArray = new Array();

  const accounts = await getAccounts();
  const lengthOrcs = await window.stakeContract.methods.numberOfStakedOrcs(accounts[0]).call();

  for (let i = 0; i < lengthOrcs; i++) {
    id = await window.stakeContract.methods.orcStakingsByOwner(accounts[0],i).call();
    tokenInfo = await window.stakeContract.methods.orcStakings(id).call();
    uri = await window.mintContract.methods.tokenURI(id).call();
    
    stakedOrcsArray.push(id);
    stakingTimestamp.set(id ,new Date(tokenInfo.timestamp*1000));
    stakedOrcsInfo.set(id, tokenInfo);
    idToURI.set(id, uri);
  }
}

async function loadUnstakedElfsOrcs(){
  var uri;
  unstakedElfsArray = new Array();
  unstakedOrcsArray = new Array();
  
  const account = await getAccounts();

  const array = await window.stakeContract.methods.allUnstaked(account[0]).call();

  for (let i = 0; i < array.length; i++) {
    var isOrc = await window.stakeContract.methods.checkIfIsOrc(array[i]).call();
    uri = await window.mintContract.methods.tokenURI(array[i]).call();

    if(!isOrc){
      unstakedElfsArray.push(array[i]);
    }
    else{
      unstakedOrcsArray.push(array[i]);
    }

    idToURI.set(array[i], uri);
  }
}

// Displaying tokens

async function displayStakedNFTS(type){
  var mainSection = document.getElementsByClassName('Staked'+ type +'sMainSection');
  var temporarySection  = document.getElementsByClassName('Staked'+ type +'sTemporary');

  var buttonClaim = document.getElementsByClassName('ButtonClaim'+type);
  var buttonUnstake = document.getElementsByClassName('ButtonUnstake'+type);

  var newSection = document.createElement('div');
  newSection.className = 'Staked'+ type +'sTemporary';

  mainSection[0].removeChild(temporarySection[0]);
  mainSection[0].appendChild(newSection);
  mainSection[0].appendChild(buttonClaim[0]);
  mainSection[0].appendChild(buttonUnstake[0]);

  if(type == "Orc"){
    var buttonAmbush = document.getElementsByClassName('ButtonAmbush');
    mainSection[0].appendChild(buttonAmbush[0]);

    await drawNFT(stakedOrcsArray,newSection,true);
  }
  else if(type == "Elf"){
    await drawNFT(stakedElfsArray,newSection,true);
  }
}

async function displayUnstakedNFTS(type){
  var mainSection = document.getElementsByClassName('Unstaked'+ type +'sMainSection');
  var temporarySection  = document.getElementsByClassName('Unstaked'+ type +'sTemporary');

  var buttonStake = document.getElementsByClassName('ButtonStake' + type);
  mainSection[0].removeChild(temporarySection[0]);

  var newSection = document.createElement('div');
  newSection.className = 'Unstaked'+ type +'sTemporary';

  mainSection[0].appendChild(newSection);
  mainSection[0].appendChild(buttonStake[0]);

  if(type == "Orc"){
    await drawNFT(unstakedOrcsArray,newSection,false);
  }
  else if(type == "Elf"){
    await drawNFT(unstakedElfsArray,newSection,false);
  }
}

async function drawNFT(typeArray, section, staked){
  typeArray.forEach(function(id) {
    if(stakedElfsArray.includes(id) || unstakedElfsArray.includes(id)){
      image = 'elf.jpeg';
    }
    else if(stakedOrcsArray.includes(id) || unstakedOrcsArray.includes(id)){
      image = 'orc.jpeg';
    }
    else{
      image = 'none.jpg';
    }

    var nft = document.createElement('section');
    nft.className = 'nft';
    nft.id = 'nft' + id;

    nft.onclick = function () {
      if(document.getElementById('nft' + id).className == 'selected'){
        document.getElementById('nft' + id).className = 'nft';
      }
      else{
        document.getElementById('nft' + id).className = 'selected';
      }
    }

    var imageHTML = document.createElement('img');
    /*imageHTML.src = idToImage.get(id);*/
    imageHTML.src = image;
    imageHTML.id = 'NFTImage';

    var tokenIdParagraph = document.createElement('p');
    tokenIdParagraph.id = 'idParagraph';
    tokenIdParagraph.innerHTML = id;

    nft.append(imageHTML);
    nft.append(tokenIdParagraph);

    if(staked){
      var stakedDate = stakingTimestamp.get(id);
      var currentDate = new Date();
      var newDate = new Date(Math.abs(currentDate-stakedDate));

      var rewardAmount = document.createElement('p');
      rewardAmount.id = "rewardTokensAmount"+id;
      rewardAmount.className = "rewardTokensAmountClass";

      var timeParagraph = document.createElement('p');
      timeParagraph.className = 'timestampParagraph';
      timeParagraph.id = 'counter' + id;
      timeParagraph.innerHTML = toFormatString(time(newDate));

      nft.appendChild(rewardAmount);
      nft.appendChild(timeParagraph);
    }

    section.appendChild(nft);
  });
}

async function loadTokens(){
  await loadStakedElfs();
  await loadStakedOrcs();
  await loadUnstakedElfsOrcs();

  getImageNFT();

  displayStakedNFTS("Elf");
  displayStakedNFTS("Orc");

  counter();
  rewards();

  displayUnstakedNFTS("Elf");
  displayUnstakedNFTS("Orc");
}

// Loading contracts

async function load(){
  loadWeb3();
  
  window.mintContract = await loadMintingContract();
  window.stakeContract = await loadStakingContract();
  window.manaContract = await loadManaContract();

  await loadTokens();
  updateMana();
  updateTotalStakedElfs();
}

// Onclick functions

async function mintWithEthereum(){
  /*
  var numberBox = document.getElementById("mintAmountEth");
  var json = await getContractsJSON();
  const accounts = await getAccounts();

  const price = await window.mintContract.methods.minthEthCost().call();
  price = web3.utils.toBN(price * numberBox.value);

  await window.wethContract.methods.approve(json.stakeContractAddress, price).send({ from: accounts[0] });
  await window.mintContract.methods.publicSale(numberBox.value).send({ from: accounts[0] });
  */
}

async function mintWithMana(){
  var numberBox = document.getElementById("mintAmount");
  var json = await getContractsJSON();
  const accounts = await getAccounts();

  price = web3.utils.toBN((10*10**18) * numberBox.value);

  for (let index = 0; index < numberBox.value; index++) {
    await window.manaContract.methods.approve(json.mintContractAddress, price).send({ from: accounts[0] });
    await window.mintContract.methods.mintOneRandom(accounts[0]).send({ from: accounts[0] });
  }
  
  setTimeout(loadTokens, 5000);

  /*
  const price = await window.mintContract.methods.manaPrice(numberbox.value);
  price = web3.utils.toBN(price);

  await window.manaContract.methods.approve(json.mintContractAddress, price).send({ from: accounts[0] });
  await window.mintContract.methods.buyWithMana(numberBox.value).send({ from: accounts[0] });
  */
}

async function ambush() {
  /*
  var arrayChecked = new Array();
  var json = getContractsJSON();
  
  stakedOrcsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    
    if (nft.className == 'selected') {
      arrayChecked.push(id);
  }
  });

  if(arrayChecked.length == 1){
    const accounts = await getAccounts();

    var cost = await window.stakeContract.methods.ambushCost(arrayChecked[0]).call();
    await window.stakeContract.methods.ambush(arrayChecked[0]).send({ from: accounts[0], value: cost });

    loadTokens();
  }
  else{
    alert("Select only one staked orc for ambush.");
  }
  */
}

async function stakeElfs(){
  var arrayChecked = new Array();
  
  unstakedElfsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    
    if (nft.className == 'selected') {
      arrayChecked.push(id);
  }
  });

  if(arrayChecked.length > 0){
    const accounts = await getAccounts();
    await window.stakeContract.methods.batchStakeElf(arrayChecked).send({ from: accounts[0] });

    loadTokens();
    updateTotalStakedElfs();
  }
  else{
    alert("Select a unstaked elf.");
  }
}

async function stakeOrcs(){
  var arrayChecked = new Array();
  
  unstakedOrcsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    
    if (nft.className == 'selected') {
      arrayChecked.push(id);
  }
  });

  if(arrayChecked.length > 0){
    const accounts = await getAccounts();
    await window.stakeContract.methods.batchStakeOrc(arrayChecked).send({ from: accounts[0] });

    loadTokens();
  }
  else{
    alert("Select a unstaked orc.");
  }
}

async function unstakeElfs(){
  var arrayChecked = new Array();
  
  stakedElfsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    
    if (nft.className == 'selected') {
      arrayChecked.push(id);
  }
  });

  if(arrayChecked.length > 0){
    const accounts = await getAccounts();
    await window.stakeContract.methods.batchUnstakeElf(arrayChecked).send({ from: accounts[0] });

    loadTokens();
    updateTotalStakedElfs();
  }
  else{
    alert("Select a staked elf.");
  }
}

async function unstakeOrcs(){
  var arrayChecked = new Array();
  
  stakedOrcsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    
    if (nft.className == 'selected') {
      arrayChecked.push(id);
  }
  });

  if(arrayChecked.length > 0){
    const accounts = await getAccounts();
    await window.stakeContract.methods.batchUnstakeOrc(arrayChecked).send({ from: accounts[0] });

    loadTokens();
  }
  else{
    alert("Select a staked orc.");
  }
}

async function selectAllElfsStake(){
  unstakedElfsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    nft.className = 'selected';
  });
}

async function selectAllOrcsStake(){
  unstakedOrcsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    nft.className = 'selected';
  });
}

async function selectAllElfsUnstake(){
  stakedElfsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    nft.className = 'selected';
  });
}

async function selectAllOrcsUnstake(){
  stakedOrcsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    nft.className = 'selected';
  });
}

async function claimElfRewards(){
  var arrayChecked = new Array();
  
  stakedElfsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    
    if (nft.className == 'selected') {
      arrayChecked.push(id);
  }
  });

  if(arrayChecked.length>0){
    const accounts = await getAccounts();
    await window.stakeContract.methods.claimManyRewards(arrayChecked,false).send({ from: accounts[0] });

    updateMana();
    loadTokens();
  }
  else{
    alert("Select a staked elf.");
  }
}

async function claimOrcRewards(){
  var arrayChecked = new Array();

  stakedOrcsArray.forEach(function(id){
    var nft = document.getElementById("nft" + id);
    
    if (nft.className == 'selected') {
      arrayChecked.push(id);
  }
  });

  if(arrayChecked.length>0){
    const accounts = await getAccounts();
    await window.stakeContract.methods.claimManyRewards(arrayChecked,false).send({ from: accounts[0] });

    updateMana();
    loadTokens();
  }
  else{
    alert("Select a staked orc.");
  }

  updateMana();
}

getContractsJSON();
load();
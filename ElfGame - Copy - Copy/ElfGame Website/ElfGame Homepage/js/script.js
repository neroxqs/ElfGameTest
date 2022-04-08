function isMobileDevice() {
    return 'ontouchstart' in window || 'onmsgesturechange' in window;
}

async function connectWallet() {
    if (isMobileDevice()) {
        const metamaskAppDeepLink = "https://metamask.app.link/dapp/zealous-darwin-80780b.netlify.app/#";
        window.location.href = metamaskAppDeepLink;
    }
    else{
        await ethereum.request({ method: 'eth_requestAccounts' });
    }

    displayWallet();
}

async function goToStakingPage() {
    if(window.ethereum){
        var accounts = await getAccounts();
        if(accounts.length > 0){
            window.location.href = "../ElfGame Staking Page/index.html";
            /*
            web3.eth.net.getId().then(async function(networkId) {
                if (networkId != 137) {
                    alert("Switch to Matic Mainnet first.");
                }else{
                    window.location.href = "../ElfGame Staking Page/index.html";
                }
            });
            */
        }
        else{
            alert("Can't access staking page. Not connected to wallet.");
        }
    }
}

async function getAccounts(){
    return await ethereum.request({ method: 'eth_accounts' });
}

async function updateAccounts(newText) {
    const walletHeader = document.getElementById('walletHeader');
    const walletFooter = document.getElementById('walletFooter');
    walletHeader.innerHTML = newText;
    walletFooter.innerHTML = newText;
}

async function checkNetwork() {
    window.web3 = new Web3(window.ethereum);
    web3.eth.net.getId().then(async function(networkId) {
        if (networkId != 137) {
            alert("Not on Matic Mainnet.");
            await ethereum.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: "0x89" }],
            });
        }
    });
}

async function displayWallet() {
    if(window.ethereum){
        const connectWalletButton = document.getElementById('connect');
        var accounts = await getAccounts();

        if(accounts.length>0){
            connectWalletButton.style.visibility = "hidden";

            updateAccounts("Your address  : " + accounts[0]);
        }
        else{
            updateAccounts("");
            connectWalletButton.style.visibility = "visible";
        }
    }
}

displayWallet();
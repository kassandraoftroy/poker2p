const ethers = require('ethers');
const hre = require('hardhat');
require('dotenv').config();

const getAction = async wallet => {
  const actionTokenArtifact = hre.artifacts.readArtifactSync('ActionToken');
  const daiTokenArtifact = hre.artifacts.readArtifactSync('ITestERC20');
  const actionContract = new ethers.Contract(
      hre.network.config.deployments.ActionToken,
      actionTokenArtifact.abi,
      wallet,
  );
  const daiContract = new ethers.Contract(
    hre.network.config.addressBook.erc20.DAI,
    daiTokenArtifact.abi,
    wallet,
  );
  let daiBalance = await daiContract.functions.balanceOf(wallet.address);
  if (Number(ethers.utils.formatEther(daiBalance.toString())) < 10) {
    const tx = await daiContract.functions.allocateTo(wallet.address, ethers.utils.parseEther("100").toString());
    console.log('\n Acquiring DAI, waiting for confirmation...');
    console.log(' tx:', tx.hash);
    let receipt;
    while (true) {
        receipt = await wallet.provider.getTransactionReceipt(tx.hash);
        if (receipt != null) {
            break;
        } else {
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
  }
  await new Promise(resolve => setTimeout(resolve, 1000));
  daiBalance = await daiContract.functions.balanceOf(wallet.address);
  if (Number(ethers.utils.formatEther(daiBalance.toString())) < 10) {
    console.log('Error: failed to acquire enough DAI');
    return
  }
  console.log('\n Acquiring ACTION with DAI...');
  let txApprove = await daiContract.functions.approve(hre.network.config.deployments.ActionToken, ethers.utils.parseEther("10").toString());
  console.log(` approval tx: ${txApprove.hash}`);
  let tx2 = await actionContract.functions.mint(ethers.utils.parseEther("10").toString(), 0, {gasLimit:200000});
  console.log(' mint tx:', tx2.hash);
  let receipt2;
  while (true) {
    receipt2 = await wallet.provider.getTransactionReceipt(tx2.hash);
    if (receipt2 != null) {
        break;
    } else {
        await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
  await new Promise(resolve => setTimeout(resolve, 1000));
  let actionBalance = await actionContract.functions.balanceOf(wallet.address);
  daiBalance = await daiContract.functions.balanceOf(wallet.address);
  console.log(`\n DAI Token Balance: ${ethers.utils.formatEther(daiBalance.toString())} DAI\n Action Token Balance: ${ethers.utils.formatEther(actionBalance.toString())} ACTION`);
};

(async () => {
  const priv = hre.network.config.accounts[0];
  const providerURL = hre.network.config.url;
  const provider = new ethers.providers.JsonRpcProvider(providerURL);
  const wallet = new ethers.Wallet(priv, provider);
  await getAction(wallet);
})();
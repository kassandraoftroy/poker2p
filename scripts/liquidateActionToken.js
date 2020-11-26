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
  let actionBalance = await actionContract.functions.balanceOf(wallet.address);
  if (Number(ethers.utils.formatEther(actionBalance.toString())) > 0) {
    console.log('\n Liquidating ACTION for DAI...');
    let tx2 = await actionContract.functions.burn(actionBalance.toString(), 0, {gasLimit:200000});
    console.log(' burn tx:', tx2.hash);
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
  } else {
    console.log("\n You dont have any Action Token");
    return
  }
  await new Promise(resolve => setTimeout(resolve, 1000));
  actionBalance = await actionContract.functions.balanceOf(wallet.address);
  let daiBalance = await daiContract.functions.balanceOf(wallet.address);
  console.log(`\n Action Token Balance: ${ethers.utils.formatEther(actionBalance.toString())} ACTION\n DAI Token Balance: ${ethers.utils.formatEther(daiBalance.toString())} DAI`);
};

(async () => {
  const priv = hre.network.config.accounts[0];
  const providerURL = hre.network.config.url;
  const provider = new ethers.providers.JsonRpcProvider(providerURL);
  const wallet = new ethers.Wallet(priv, provider);
  await getAction(wallet);
})();
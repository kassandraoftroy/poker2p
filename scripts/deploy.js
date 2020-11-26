const ethers = require('ethers');
const hre = require('hardhat');
require('dotenv').config();

const deploy = async wallet => {
  let actionToken = hre.network.config.deployments.ActionToken;
  let mentalPoker = hre.network.config.deployments.MentalPoker;
  let highCardGame = hre.network.config.deployments.HighCardGameState;
  let headsUp = hre.network.config.deployments.HeadsUpTables;
  if (actionToken == '') {
    const artifact = hre.artifacts.readArtifactSync('ActionToken');
    const factory = new ethers.ContractFactory(
      artifact.abi,
      artifact.bytecode,
      wallet,
    );
    const deployTx = factory.getDeployTransaction(
      "Action Token",
      "ACTION",
      18,
      ethers.utils.parseEther("1000000").toString(),
      400000,
      hre.network.config.addressBook.erc20.DAI
    );
    deployTx.gasLimit = 6000000;
    deployTx.gasPrice = ethers.utils.parseUnits('2', 'gwei');
    try {
      const tx = await wallet.sendTransaction(deployTx);
      let receipt;
      console.log('\n Waiting for deploy ActionToken TX to get mined...');
      console.log(' tx:', tx.hash);
      while (true) {
        receipt = await wallet.provider.getTransactionReceipt(tx.hash);
        if (receipt != null) {
          break;
        } else {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
      console.log(' Deploy ActionToken TX successfully mined ✅');
      console.log(' contract:', receipt.contractAddress);
      actionToken = receipt.contractAddress;
      const artifact2 = hre.artifacts.readArtifactSync('ITestERC20');
      const daiContract = new ethers.Contract(
        hre.network.config.addressBook.erc20.DAI,
        artifact2.abi,
        wallet,
      );
      let daiBalance = await daiContract.functions.balanceOf(wallet.address);
      if (Number(ethers.utils.formatEther(daiBalance.toString())) < 100) {
        const tx2 = await daiContract.functions.allocateTo(wallet.address, ethers.utils.parseEther("100").toString());
        console.log('\n Acquiring at least 100 DAI, waiting for confirmation...');
        console.log(' tx:', tx2.hash);
        while (true) {
            receipt = await wallet.provider.getTransactionReceipt(tx2.hash);
            if (receipt != null) {
              break;
            } else {
              await new Promise(resolve => setTimeout(resolve, 2000));
            }
        }
      }
      await new Promise(resolve => setTimeout(resolve, 2000));
      daiBalance = await daiContract.functions.balanceOf(wallet.address);
      if (Number(ethers.utils.formatEther(daiBalance.toString())) < 100) {
          console.log('failed to acquire enough DAI');
          return
      } else {
        console.log(' DAI acquired ✅');
      }
      const tx3 = await daiContract.functions.transfer(
        actionToken,
        ethers.utils.parseEther("100").toString()
      );
      console.log(' intializing bonded token with 100 DAI:', tx3.hash);
    } catch (e) {
      console.log('error deploying contract:', e.message);
    }
  } else {
    console.log('\n Action Token contract already deployed');
  }
  if (mentalPoker == '') {
    try {
      const artifact = hre.artifacts.readArtifactSync('MentalPoker');
      const factory = new ethers.ContractFactory(
        artifact.abi,
        artifact.bytecode,
        wallet,
      );
      let cardInputs = [...Array(54).keys()].slice(2);
      const deployTx = factory.getDeployTransaction(cardInputs);
      deployTx.gasLimit = 6000000;
      deployTx.gasPrice = ethers.utils.parseUnits('2', 'gwei');
      const tx = await wallet.sendTransaction(deployTx);
      let receipt;
      console.log('\n Waiting for deploy MentalPoker TX to get mined...');
      console.log(' tx:', tx.hash);
      while (true) {
        receipt = await wallet.provider.getTransactionReceipt(tx.hash);
        if (receipt != null) {
          break;
        } else {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
      console.log(' Deploy MentalPoker TX successfully mined ✅');
      console.log(' contract:', receipt.contractAddress);
      mentalPoker = receipt.contractAddress;
    } catch (e) {
      console.log('error deploying test contract:', e.message);
    }
  } else {
    console.log('\n Mental Poker contract already deployed');
  }
  if (highCardGame == '' || mentalPoker!=hre.network.config.deployments.MentalPoker) {
    try {
      const artifact = hre.artifacts.readArtifactSync('HighCardGameState');
      const factory = new ethers.ContractFactory(
        artifact.abi,
        artifact.bytecode,
        wallet,
      );
      const deployTx = factory.getDeployTransaction(mentalPoker);
      deployTx.gasLimit = 6000000;
      deployTx.gasPrice = ethers.utils.parseUnits('2', 'gwei');
      const tx = await wallet.sendTransaction(deployTx);
      let receipt;
      console.log('\n Waiting for deploy HighCardGameState TX to get mined...');
      console.log(' tx:', tx.hash);
      while (true) {
        receipt = await wallet.provider.getTransactionReceipt(tx.hash);
        if (receipt != null) {
          break;
        } else {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
      console.log(' Deploy HighCardGameState TX successfully mined ✅');
      console.log(' contract:', receipt.contractAddress);
      highCardGame = receipt.contractAddress;
    } catch (e) {
      console.log('error deploying test contract:', e.message);
    }
  } else {
    console.log('\n High Card Game State contract already deployed');
  }
  if (headsUp == '' || highCardGame!=hre.network.config.deployments.HighCardGameState || actionToken!=hre.network.config.deployments.ActionToken) {
    try {
        const artifact = hre.artifacts.readArtifactSync('HeadsUpTables');
        const factory = new ethers.ContractFactory(
          artifact.abi,
          artifact.bytecode,
          wallet,
        );
        const deployTx = factory.getDeployTransaction(highCardGame, actionToken);
        deployTx.gasLimit = 6000000;
        deployTx.gasPrice = ethers.utils.parseUnits('2', 'gwei');
        const tx = await wallet.sendTransaction(deployTx);
        let receipt;
        console.log('\n Waiting for deploy HeadsUpTables TX to get mined...');
        console.log(' tx:', tx.hash);
        while (true) {
          receipt = await wallet.provider.getTransactionReceipt(tx.hash);
          if (receipt != null) {
            break;
          } else {
            await new Promise(resolve => setTimeout(resolve, 2000));
          }
        }
        console.log(' Deploy HeadsUpTables TX successfully mined ✅');
        console.log(' contract:', receipt.contractAddress);
      } catch (e) {
        console.log('error deploying test contract:', e.message);
      }
  } else {
    console.log('\n Heads Up Tables contract already deployed');
  }
};

(async () => {
  const priv = hre.network.config.accounts[0];
  const providerURL = hre.network.config.url;
  const provider = new ethers.providers.JsonRpcProvider(providerURL);
  const wallet = new ethers.Wallet(priv, provider);
  await deploy(wallet);
})();

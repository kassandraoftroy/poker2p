require('dotenv').config();
const INFURA_ID = process.env.INFURA_ID;
const PROVIDER_PK = process.env.PROVIDER_SK;
if (
  PROVIDER_PK == null ||
  INFURA_ID == null
) {
  console.log('\n !! IMPORTANT !!\n Must set .env vars before running hardhat');
  throw 'set env variables';
}

module.exports = {
  defaultNetwork: 'rinkeby',
  networks: {
    rinkeby: {
      accounts: [PROVIDER_PK],
      chainId: 4,
      url: `https://rinkeby.infura.io/v3/${INFURA_ID}`,
      addressBook: {
        erc20: {
          DAI: '0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa',
          '0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa': 'DAI',
        },
      },
      deployments: {
        ActionToken: "0x7c3Ebd16f11F0C688B8A76B6F15fDd469fF5CA5c",
        MentalPoker: "0xb7D70ad5f587aE83C5c9BB2539d6c8D29889f260",
        HighCardGameState: "0x7641109C73CB4959D565026661f69A4E8DB9b7a9",
        HeadsUpTables: "0xc4E9Ef31b4DDb68535e656569f36977b35fcA213"
      }
    }
  },
  solidity: {
    version: '0.5.0',
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
};

require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork : "goerli",
  networks: {
    goerli:{
      url:process.env.ALCHEMY_KEY,
      accounts:[process.env.PRIVATE_KEY],
    }
  },
  etherscan: {
    apiKey:process.env.ETHERSCAN_API_KEY,
  }
};
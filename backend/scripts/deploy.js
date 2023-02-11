const { ethers } = require("hardhat");
require("dotenv").config({ path: ".env" });
const { ICO_TOKEN_ADDRESS } = require("../constants");

async function main() {
  const icoTokenAddress = ICO_TOKEN_ADDRESS;
 
  const SimpleDex = await ethers.getContractFactory("SimpleDEX");

  // here we deploy the contract
  const simpleDex = await SimpleDex.deploy(
    icoTokenAddress
  );
  await simpleDex.deployed();

  console.log("SimpleDEX Contract Address:", simpleDex.address);
}

// Call the main function and catch if there is any error
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
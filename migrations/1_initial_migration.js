const SCHToken = artifacts.require("SCH");
const USDTToken = artifacts.require("USDT");
const Presale = artifacts.require("Presale");

module.exports = async (deployer) => {
    console.log("Deployer", deployer.networks.development.from);

    await deployer.deploy(SCHToken);
    const schToken = await SCHToken.deployed();
    console.log("SCHToken", schToken.address);

    await deployer.deploy(USDTToken);
    const usdtToken = await USDTToken.deployed();
    console.log("USDTToken", usdtToken.address);
  
    await deployer.deploy(Presale, schToken.address, usdtToken.address, deployer.networks.development.from);
    const presaleContract = await Presale.deployed();
    console.log("Presale", presaleContract.address);
};
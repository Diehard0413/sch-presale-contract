const SCHToken = artifacts.require("SCH");
const Presale = artifacts.require("Presale");

module.exports = async (deployer) => {
    await deployer.deploy(SCHToken);
    const token = await SCHToken.deployed();
    console.log("SCHToken", token.address);
  
    await deployer.deploy(Presale);
    const presaleContract = await Presale.deployed();
    console.log("Presale", presaleContract.address);
};
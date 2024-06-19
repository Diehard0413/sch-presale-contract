const SCHToken = artifacts.require("SCH");
const USDTToken = artifacts.require("USDT");
const Presale = artifacts.require("Presale");

contract('test for all', async accounts => {
    let schToken;
    let usdtToken;
    let presaleContract;

    before(async () => {
        schToken = await SCHToken.deployed();
        usdtToken = await USDTToken.deployed();
        presaleContract = await Presale.deployed();

        console.log(accounts);

        console.log("SCHToken: ", schToken.address);
        console.log("USDTToken: ", usdtToken.address);
        console.log("Presale: ", presaleContract.address);
    })

    it('distribution of token', async () => {

    })
})
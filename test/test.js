const SCHToken = artifacts.require("SCH");
const Presale = artifacts.require("Presale");

contract('test for all', async accounts => {
    let token;
    let presaleContract;

    before(async () => {
        token = await SCHToken.deployed();
        presaleContract = await Presale.deployed();

        console.log(accounts);

        console.log("Token: ", token.address);
        console.log("Presale: ", presaleContract.address);
    })

    it('distribution of token', async () => {

    })
})
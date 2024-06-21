const SCHToken = artifacts.require("SCH");
const USDTToken = artifacts.require("USDT");
const Presale = artifacts.require("Presale");

const sleep = ms => new Promise(r => setTimeout(r, ms));

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

    it('distribution of USDT token', async () => {
        console.log("~~~~~~~~~~USDT token's balances before distribution~~~~~~~~~~");
        console.log("Owner USDT balance: ", (await usdtToken.balanceOf(accounts[0])).toString());
        console.log("User1 USDT balance: ", (await usdtToken.balanceOf(accounts[1])).toString());
        console.log("User2 USDT balance: ", (await usdtToken.balanceOf(accounts[2])).toString());

        await usdtToken.transfer(accounts[1], web3.utils.toBN("10000000000"), {from: accounts[0]});
        await usdtToken.transfer(accounts[2], web3.utils.toBN("20000000000"), {from: accounts[0]});
        
        console.log("~~~~~~~~~~USDT token's balances after distribution~~~~~~~~~~");
        console.log("Owner USDT balance: ", (await usdtToken.balanceOf(accounts[0])).toString());
        console.log("User1 USDT balance: ", (await usdtToken.balanceOf(accounts[1])).toString());
        console.log("User2 USDT balance: ", (await usdtToken.balanceOf(accounts[2])).toString());
    })

    it('Fund SCH token to the presale contract', async () => {
        console.log("~~~~~~~~~~SCH token's balances before fund~~~~~~~~~~");
        console.log("Owner SCH balance: ", (await schToken.balanceOf(accounts[0])).toString());
        console.log("Contract SCH balance: ", (await schToken.balanceOf(presaleContract.address)).toString());

        await schToken.transfer(presaleContract.address, web3.utils.toBN("2000000000000000000000000"), {from: accounts[0]});
        
        console.log("~~~~~~~~~~SCH token's balances after fund~~~~~~~~~~");
        console.log("Owner SCH balance: ", (await schToken.balanceOf(accounts[0])).toString());
        console.log("Contract SCH balance: ", (await schToken.balanceOf(presaleContract.address)).toString());
    })

    it('Initialize presale contract', async () => {
        await presaleContract.initialize(schToken.address, usdtToken.address, {from: accounts[0]});
    })

    it('Create 1st presale round', async () => {
        const CUR_TIME = (new Date().getTime() / 1000).toFixed(0);
        console.log("Current timestamp: ", CUR_TIME);

        const START_TIME = web3.utils.toBN(CUR_TIME.toString());
        const END_TIME = web3.utils.toBN((Number(CUR_TIME) + 30).toString());
        const CLAIM_TIME = web3.utils.toBN((Number(CUR_TIME) + 60).toString());
        const MIN_AMOUNT = web3.utils.toBN("10");
        const PRICE = web3.utils.toBN("10000");
        const AFFILIATE_FEE = web3.utils.toBN("1000");
        const VESTING_DURATION = web3.utils.toBN("6");
        console.log("Vesting duration: ", VESTING_DURATION.toString());

        flag = await presaleContract.hasRole(await presaleContract.DEFAULT_ADMIN_ROLE(), accounts[0]);
        console.log("Owner Role check", flag);

        let tx = await presaleContract.createRound(
            START_TIME,
            END_TIME,
            CLAIM_TIME,
            MIN_AMOUNT,
            PRICE,
            AFFILIATE_FEE,
            VESTING_DURATION,
            {from: accounts[0]}
        );

        console.log("1st presale contract is created", tx.tx);
    })

    it('Proceed 1st presale round', async () => {
        console.log("Referrer USDT balance: ", (await usdtToken.balanceOf(accounts[3])).toString());
        console.log("User1 USDT balance: ", (await usdtToken.balanceOf(accounts[1])).toString());
        console.log("User2 USDT balance: ", (await usdtToken.balanceOf(accounts[2])).toString());

        let tx = await usdtToken.approve(presaleContract.address, web3.utils.toBN("100000000"), {from: accounts[1]});
        
        console.log("User1 approved 100 USDT token to presale contract", tx.tx);
        
        console.log("User1 depositing with referrer", accounts[3]);

        tx = await presaleContract.deposit(
            web3.utils.toBN("0"),
            web3.utils.toBN("100"),
            accounts[3],
            {from: accounts[1]}
        );

        console.log("User1 deposited", tx.tx);

        tx = await usdtToken.approve(presaleContract.address, web3.utils.toBN("200000000"), {from: accounts[2]});
        
        console.log("User2 approved 200 USDT token to presale contract", tx.tx);
        
        console.log("User2 depositing with referrer", accounts[3]);
        
        tx = await presaleContract.deposit(
            web3.utils.toBN("0"),
            web3.utils.toBN("200"),
            accounts[3],
            {from: accounts[2]}
        );

        console.log("User2 deposited", tx.tx);

        console.log("Referrer USDT balance: ", (await usdtToken.balanceOf(accounts[3])).toString());
        console.log("User1 USDT balance: ", (await usdtToken.balanceOf(accounts[1])).toString());
        console.log("User2 USDT balance: ", (await usdtToken.balanceOf(accounts[2])).toString());
    })

    it('Claim affiliate reward', async () => {
        console.log("Contract USDT balance: ", (await usdtToken.balanceOf(presaleContract.address)).toString());
        console.log("User3 USDT balance: ", (await usdtToken.balanceOf(accounts[3])).toString());

        await presaleContract.claimAffiliateReward({from: accounts[3]});

        console.log("Contract USDT balance: ", (await usdtToken.balanceOf(presaleContract.address)).toString());
        console.log("User3 USDT balance: ", (await usdtToken.balanceOf(accounts[3])).toString());
    })


    it('Set interval for claim feature', async () => {
        await sleep(55000);

        let curTimeStamp = (new Date().getTime() / 1000).toFixed(0);
        let stages = await presaleContract.stages(0);
        console.log("Current timestamp: ", curTimeStamp);
        console.log("Time to start: ", stages.timeToStart.toString());
        console.log("Time to end: ", stages.timeToEnd.toString());
        console.log("Time to claim: ", stages.timeToClaim.toString());
    })    

    it('Claim on 1st presale round', async () => {
        console.log("Contract SCH balance: ", (await schToken.balanceOf(presaleContract.address)).toString());
        console.log("User1 SCH balance: ", (await schToken.balanceOf(accounts[1])).toString());
        console.log("User2 SCH balance: ", (await schToken.balanceOf(accounts[2])).toString());
        
        let denominator = await presaleContract.DENOMINATOR();
        let stages = await presaleContract.stages(0);
        console.log("SCH token price: ", stages.price.toString());

        let userDeposited = await presaleContract.userDeposited(0, accounts[1]);
        let userClaimed = await presaleContract.userClaimed(0, accounts[1]);
        let vestedAmount = userDeposited * denominator / stages.price;

        console.log("User1 claimed amount: ", userClaimed.toString());
        console.log("User1 vested amount: ", vestedAmount.toString());

        userDeposited = await presaleContract.userDeposited(0, accounts[2]);
        userClaimed = await presaleContract.userClaimed(0, accounts[2]);
        vestedAmount = userDeposited * denominator / stages.price;

        console.log("User2 claimed amount: ", userClaimed.toString());
        console.log("User2 vested amount: ", vestedAmount.toString());

        let tx = await presaleContract.claim(
            web3.utils.toBN("0"),
            {from: accounts[1]}
        );

        console.log("User1 claimed", tx.tx);
        
        tx = await presaleContract.claim(
            web3.utils.toBN("0"),
            {from: accounts[2]}
        );

        console.log("User2 claimed", tx.tx);

        console.log("Contract SCH balance: ", (await schToken.balanceOf(presaleContract.address)).toString());
        console.log("User1 SCH balance: ", (await schToken.balanceOf(accounts[1])).toString());
        console.log("User2 SCH balance: ", (await schToken.balanceOf(accounts[2])).toString());
    })

    it('Rescue USDT funds', async () => {
        console.log("Contract USDT balance: ", (await usdtToken.balanceOf(presaleContract.address)).toString());
        console.log("Owner USDT balance: ", (await usdtToken.balanceOf(accounts[0])).toString());

        await presaleContract.RescueFunds({from: accounts[0]});

        console.log("Contract USDT balance: ", (await usdtToken.balanceOf(presaleContract.address)).toString());
        console.log("Owner USDT balance: ", (await usdtToken.balanceOf(accounts[0])).toString());
    })

    it('Rescue SCH tokens', async () => {
        console.log("Contract SCH balance: ", (await schToken.balanceOf(presaleContract.address)).toString());
        console.log("Owner SCH balance: ", (await schToken.balanceOf(accounts[0])).toString());

        await presaleContract.RescueToken({from: accounts[0]});

        console.log("Contract SCH balance: ", (await schToken.balanceOf(presaleContract.address)).toString());
        console.log("Owner SCH balance: ", (await schToken.balanceOf(accounts[0])).toString());
    })

    it('Grant Role Check', async () => {
        let ROLE = await presaleContract.OWNER_ROLE();

        let flag = await presaleContract.hasRole(ROLE, accounts[1]);
        console.log("User1 Role check", flag);

        await presaleContract.grantRole(ROLE, accounts[1], {from: accounts[0]});

        flag = await presaleContract.hasRole(ROLE, accounts[1]);
        console.log("User1 Role check", flag);

        await presaleContract.revokeRole(ROLE, accounts[1], {from: accounts[0]});

        flag = await presaleContract.hasRole(ROLE, accounts[1]);
        console.log("User1 Role check", flag);
    })
})

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IAccessControl.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC20Metadata.sol";
import "./libraries/AddressUpgradeable.sol";
import "./tokens/ERC165Upgradeable.sol";
import "./utils/AccessControlUpgradeable.sol";
import "./utils/ContextUpgradeable.sol";
import "./utils/Initializable.sol";
import "./utils/OwnableUpgradeable.sol";
import "./utils/ReentrancyGuardUpgradeable.sol";

contract Presale is OwnableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    uint256 public constant DENOMINATOR = 10000;
    uint256 public constant MONTH = 30 days;
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    IERC20Metadata public schAddress; // SCH token address
    IERC20Metadata public saleAddress; // USDT address

    struct Stage {
        uint256 timeToStart;
        uint256 timeToEnd;
        uint256 timeToClaim;
        uint256 minAmount; // Token amount without considering decimals
        uint256 totalSale;
        uint256 price; // Price for SCH token, multiplied by 100 (e.g., 10000 = $1)
        uint256 affiliateFee; // Percentage fee for the affiliate, multiplied by 10000 (e.g., 5% = 500)
        uint256 vestingPeriod; // Total months for vesting period
        uint256 vestedAmount; // Total vested amount for the stage
    }

    Stage[] public stages;

    mapping(uint256 => mapping(address => uint256)) public userDeposited; // Stage ID => (User => Deposited Amount)
    mapping(uint256 => mapping(address => uint256)) public userClaimed; // Stage ID => (User => Claimed amount)
    mapping(uint256 => mapping(address => uint256)) public userLastClaimed; // Stage ID => (User => Last claimed timestamp)
    mapping(address => uint256) public affiliateRewards;

    event Deposit(address indexed _from, uint256 indexed _stage, uint256 _amount, address indexed _affiliate);
    event Claim(address indexed _user, uint256 indexed _stage, uint256 _amount);
    event AffiliateRewardClaimed(address indexed _affiliate, uint256 _amount);
    event RoundCreated(uint256 indexed _stageId, uint256 _timeToStart, uint256 _timeToEnd, uint256 _timeToClaim, uint256 _minimumSCHAmount, uint256 _price, uint256 _affiliateFee, uint256 _vestingPeriod);
    event RoundUpdated(uint256 indexed _stageId, uint256 _timeToStart, uint256 _timeToEnd, uint256 _timeToClaim, uint256 _minimumSCHAmount, uint256 _price, uint256 _affiliateFee, uint256 _vestingPeriod);
    event SaleAddressUpdated(address indexed _newAddress);
    event Withdrawal(address indexed _to, uint256 _amount, string _tokenType);

    receive() external payable {
        revert("Presale: Contract does not accept native currency");
    }

    fallback() external payable {
        revert("Presale: Contract does not accept native currency");
    }

    modifier onlyOwners() {
        require(hasRole(OWNER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Presale: Caller is not an owner");
        _;
    }

    function initialize(address _schAddr, address _saleAddr) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        schAddress = IERC20Metadata(_schAddr);
        saleAddress = IERC20Metadata(_saleAddr);        
    }

    function createRound(
        uint256 _timeToStart,
        uint256 _timeToEnd,
        uint256 _timeToClaim,
        uint256 _minAmount,
        uint256 _price,
        uint256 _affiliateFee,
        uint256 _vestingPeriod
    ) external onlyOwners {
        stages.push(Stage({
            timeToStart: _timeToStart,
            timeToEnd: _timeToEnd,
            timeToClaim: _timeToClaim,
            minAmount: _minAmount,
            totalSale: 0,
            price: _price,
            affiliateFee: _affiliateFee,
            vestingPeriod: _vestingPeriod,
            vestedAmount: 0
        }));

        emit RoundCreated(stages.length - 1, _timeToStart, _timeToEnd, _timeToClaim, _minAmount, _price, _affiliateFee, _vestingPeriod);
    }

    function updateStage(
        uint256 _stageId,
        uint256 _timeToStart,
        uint256 _timeToEnd,
        uint256 _timeToClaim,
        uint256 _minAmount,
        uint256 _price,
        uint256 _affiliateFee,
        uint256 _vestingPeriod
    ) external onlyOwners {
        require(_stageId < stages.length, "Presale: Invalid stage ID");

        Stage storage stage = stages[_stageId];
        stage.timeToStart = _timeToStart;
        stage.timeToEnd = _timeToEnd;
        stage.timeToClaim = _timeToClaim;
        stage.minAmount = _minAmount;
        stage.price = _price;
        stage.affiliateFee = _affiliateFee;
        stage.vestingPeriod = _vestingPeriod;

        emit RoundUpdated(_stageId, _timeToStart, _timeToEnd, _timeToClaim, _minAmount, _price, _affiliateFee, _vestingPeriod);
    }

    function deposit(uint256 _stageId, uint256 _amount, address _affiliate) external nonReentrant {
        require(_stageId < stages.length, "Presale: Invalid stage ID");

        Stage storage stage = stages[_stageId];
        require(block.timestamp >= stage.timeToStart && block.timestamp <= stage.timeToEnd, "Presale: Not presale period");
        require(_amount >= stage.minAmount, "Invalid request: minimum deposit amount not met");
        require(saleAddress.transferFrom(msg.sender, address(this), _amount * (10 ** saleAddress.decimals())), "Presale: Token transfer failed");

        uint256 depositAmount = _amount;
        uint256 affiliateReward = 0;

        if (_affiliate != address(0) && _affiliate != msg.sender) {
            affiliateReward = (depositAmount * stage.affiliateFee) / DENOMINATOR;
            affiliateRewards[_affiliate] += affiliateReward;
            depositAmount -= affiliateReward;
        }

        userDeposited[_stageId][msg.sender] += depositAmount;
        stage.totalSale += depositAmount;

        emit Deposit(msg.sender, _stageId, depositAmount, _affiliate);
    }

    function claim(uint256 _stageId) external {
        require(_stageId < stages.length, "Presale: Invalid stage ID");

        Stage storage stage = stages[_stageId];
        require(block.timestamp > stage.timeToClaim, "Presale: Invalid claim time!");
        require(userDeposited[_stageId][msg.sender] > 0, "Presale: Invalid claim amount!");

        uint256 vested = calculateVestedAmount(_stageId, msg.sender);
        require(vested > 0, "Presale: No vested tokens available for claim");
        
        uint256 lastClaimed = userLastClaimed[_stageId][msg.sender];
        require(block.timestamp >= lastClaimed + MONTH, "Presale: Can only claim once per month");

        userClaimed[_stageId][msg.sender] += vested;
        userLastClaimed[_stageId][msg.sender] = block.timestamp;
        
        require(schAddress.transfer(msg.sender, vested * (10 ** schAddress.decimals())), "Presale: Token transfer failed");

        emit Claim(msg.sender, _stageId, vested);
    }

    function calculateVestedAmount(uint256 _stageId, address _user) public view returns (uint256) {
        Stage storage stage = stages[_stageId];
        uint256 deposited = userDeposited[_stageId][_user];
        uint256 claimed = userClaimed[_stageId][_user];
        uint256 vestedAmount = (deposited * DENOMINATOR) / stage.price;
        uint256 timeElapsed = block.timestamp - stage.timeToClaim;

        if (timeElapsed >= stage.timeToClaim + stage.vestingPeriod * MONTH) {
            return vestedAmount - claimed;
        }

        uint256 monthsElapsed = timeElapsed / MONTH;

        uint256 monthlyVesting = vestedAmount / stage.vestingPeriod;

        uint256 vested = monthlyVesting * (monthsElapsed + 1);

        if (vested > vestedAmount) {
            vested = vestedAmount;
        }

        return vested - claimed;
    }

    function claimAffiliateReward() external {
        uint256 reward = affiliateRewards[msg.sender];
        require(reward > 0, "Presale: No affiliate rewards");

        affiliateRewards[msg.sender] = 0;
        require(saleAddress.transfer(msg.sender, reward * (10 ** saleAddress.decimals())), "Presale: Token transfer failed");

        emit AffiliateRewardClaimed(msg.sender, reward);
    }

    function RescueFunds() external onlyOwners returns (bool) {
        uint256 balance = saleAddress.balanceOf(address(this));
        bool success = saleAddress.transfer(msg.sender, balance);

        emit Withdrawal(msg.sender, balance, "saleToken");
        return success;
    }

    function RescueToken() external onlyOwners returns (bool) {
        uint256 balance = schAddress.balanceOf(address(this));
        bool success = schAddress.transfer(msg.sender, balance);

        emit Withdrawal(msg.sender, balance, "schToken");
        return success;
    }

    function setSaleTokenAddress(address _address) external onlyOwners {
        saleAddress = IERC20Metadata(_address);

        emit SaleAddressUpdated(_address);
    } 
}

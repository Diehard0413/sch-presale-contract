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
    }

    Stage[] public stages;

    mapping(uint256 => mapping(address => uint256)) public userDeposited; // Stage ID => (User => Deposited Amount)
    mapping(uint256 => mapping(address => bool)) public userClaimed; // Stage ID => (User => Claimed)
    mapping(address => uint256) public affiliateRewards;

    event Deposit(address indexed _from, uint256 indexed _stage, uint256 _amount, address indexed _affiliate);
    event Claim(address indexed _user, uint256 indexed _stage, uint256 _amount);
    event AffiliateRewardClaimed(address indexed _affiliate, uint256 _amount);
    event RoundCreated(uint256 indexed _stageId, uint256 _timeToStart, uint256 _timeToEnd, uint256 _timeToClaim, uint256 _minimumSCHAmount, uint256 _price, uint256 _affiliateFee);
    event RoundUpdated(uint256 indexed _stageId, uint256 _timeToStart, uint256 _timeToEnd, uint256 _timeToClaim, uint256 _minimumSCHAmount, uint256 _price, uint256 _affiliateFee);
    event SaleAddressUpdated(address indexed _newAddress);
    event Withdrawal(address indexed _to, uint256 _amount, string _tokenType);

    receive() external payable {
        revert("Presale: Contract does not accept native currency");
    }

    fallback() external payable {
        revert("Presale: Contract does not accept native currency");
    }

    modifier onlyOwners() {
        require(hasRole(OWNER_ROLE, msg.sender), "Presale: Caller is not an owner");
        _;
    }

    function initialize(address _schAddr, address _saleAddr) public initializer {
        __Ownable_init();

        schAddress = IERC20Metadata(_schAddr);
        saleAddress = IERC20Metadata(_saleAddr);

        _grantRole(OWNER_ROLE, msg.sender);
    }

    function createRound(
        uint256 _timeToStart,
        uint256 _timeToEnd,
        uint256 _timeToClaim,
        uint256 _minAmount,
        uint256 _price,
        uint256 _affiliateFee
    ) external onlyOwners {
        stages.push(Stage({
            timeToStart: _timeToStart,
            timeToEnd: _timeToEnd,
            timeToClaim: _timeToClaim,
            minAmount: _minAmount,
            totalSale: 0,
            price: _price,
            affiliateFee: _affiliateFee
        }));

        emit RoundCreated(stages.length - 1, _timeToStart, _timeToEnd, _timeToClaim, _minAmount, _price, _affiliateFee);
    }

    function updateStage(
        uint256 _stageId,
        uint256 _timeToStart,
        uint256 _timeToEnd,
        uint256 _timeToClaim,
        uint256 _minAmount,
        uint256 _price,
        uint256 _affiliateFee
    ) external onlyOwners {
        require(_stageId < stages.length, "Presale: Invalid stage ID");

        Stage storage stage = stages[_stageId];
        stage.timeToStart = _timeToStart;
        stage.timeToEnd = _timeToEnd;
        stage.timeToClaim = _timeToClaim;
        stage.minAmount = _minAmount;
        stage.price = _price;
        stage.affiliateFee = _affiliateFee;

        emit RoundUpdated(_stageId, _timeToStart, _timeToEnd, _timeToClaim, _minAmount, _price, _affiliateFee);
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
        require(!userClaimed[_stageId][msg.sender], "Presale: Already claimed!");

        uint256 claimable = (userDeposited[_stageId][msg.sender] * DENOMINATOR) / stage.price;
        userClaimed[_stageId][msg.sender] = true;

        require(schAddress.transfer(msg.sender, claimable * (10 ** schAddress.decimals())), "Presale: Token transfer failed");

        emit Claim(msg.sender, _stageId, claimable);
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

    function grantOwnerRole(address account) external {
        grantRole(OWNER_ROLE, account);
    }

    function revokeOwnerRole(address account) external {
        revokeRole(OWNER_ROLE, account);
    }
}
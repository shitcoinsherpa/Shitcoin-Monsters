// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Roles is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR");

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
    }

    modifier onlyMinter() {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Roles: caller does not have the MINTER role"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Roles: caller does not have the OPERATOR role"
        );
        _;
    }
}

interface IERC721 is IERC165 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function mint(address to) external;
}

// Stake to get MONs
contract StakeForMONs is Roles {
    using SafeMath for uint256;

    IERC20 public SMONToken;
    IERC721 public MON;

    // min $SMON amount required to stake
    uint256 public minStake = 10 * 10**18;

    // amount of points needed to redeem a MON, roughly 1 point is given each day;
    uint256 public MONPrice = 500 * 10**18;
    uint256 public totalStaked;

    mapping(address => uint256) public balance;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public points;

    event Staked(address who, uint256 amount);
    event Withdrawal(address who, uint256 amount);
    event MONMinted(address to);

    event StakeReqChanged(uint256 newAmount);
    event PriceOfMONChanged(uint256 newAmount);

    constructor(address _MON, address _SMONToken) public {
        MON = IERC721(_MON);
        SMONToken = IERC20(_SMONToken);
    }

    // changes stake requirement
    function changeStakeReq(uint256 _newAmount) external onlyOperator {
        minStake = _newAmount;
        emit StakeReqChanged(_newAmount);
    }

    function changePriceOfNFT(uint256 _newAmount) external onlyOperator {
        MONPrice = _newAmount;
        emit PriceOfMONChanged(_newAmount);
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            points[account] = earned(account);
            lastUpdateTime[account] = block.timestamp;
        }
        _;
    }

    //calculate how many points earned so far, this needs to give roughly 1 point a day per 5 tokens staked?.
    function earned(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        return
            balance[account]
                .mul(blockTime.sub(lastUpdateTime[account]).mul(2314814814000))
                .div(1e18)
                .add(points[account]);
    }

    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(
            _amount >= minStake,
            "You need to stake at least the min $SMON"
        );

        // transfer tokens to this address to stake them
        totalStaked = totalStaked.add(_amount);
        balance[msg.sender] = balance[msg.sender].add(_amount);
        SMONToken.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    // withdraw part of your stake
    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Amount can't be 0");
        require(totalStaked >= amount);
        balance[msg.sender] = balance[msg.sender].sub(amount);
        totalStaked = totalStaked.sub(amount);
        // transfer erc20 back from the contract to the user
        SMONToken.transfer(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    // withdraw all your amount staked
    function exit() external {
        withdraw(balance[msg.sender]);
    }

    //redeem a MON based on a set points price
    function redeem() public updateReward(msg.sender) {
        require(
            points[msg.sender] >= MONPrice,
            "Not enough points to redeem MON"
        );
        points[msg.sender] = points[msg.sender].sub(MONPrice);
        MON.mint(msg.sender);
        emit MONMinted(msg.sender);
    }
}
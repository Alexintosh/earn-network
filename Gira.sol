pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-solidity/master/contracts/token/ERC20/ERC20Mintable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-solidity/master/contracts/token/ERC20/ERC20Burnable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-solidity/master/contracts/token/ERC20/ERC20Detailed.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-solidity/master/contracts/token/ERC20/IERC20.sol";

interface iToken {
    function mint(address receiver, uint256 depositAmount) external returns (uint256 mintAmount);

    function burn(
        address receiver,
        uint256 burnAmount)
        external
        returns (uint256 loanAmountPaid);

    function claimLoanToken()
        external
        returns (uint256 claimedAmount);

    function donateAsset(
        address tokenAddress)
        external
        returns (bool);
    
    function assetBalanceOf(
        address _owner)
        external
        view
        returns (uint256);
        
    function tokenPrice()
        external
        view
        returns (uint256 price);
}

interface cToken {
    function mint(uint mintAmount) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external  returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function balanceOf(address account) external view returns (uint);
}

contract Girasol is ERC20Mintable, ERC20Burnable {
    string public constant name = "Earn DAI";
    string public constant symbol = "eDAI";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 0 * (10 ** uint256(decimals));
    uint256 public constant POOLSIZE = 0 * (10 ** uint256(decimals));
    uint block_start;
    IERC20 DAI;
    iToken iDAI;
    cToken cDAI;
    uint256 selected_protocol; // 0 = Fulcum , 1 = Compound
    
    
    // Tokens
    address fake = 0xaD6D458402F60fD3Bd25163575031ACDce07538D;
    address ciao_token = 0x7227B1179c97f420DCD3941E532656398F698592;
    address dai_ropsten = 0x25a01a05C188DaCBCf1D61Af55D4a5B4021F7eeD;
    
    /*
     *  Storage
     */
    mapping (address => Contribution) public contributions;
    
    struct Contribution {
        uint256 amount;
        uint block;
        address owner;
    }
    
    struct State {
        uint256 Fulcrum;
        uint256 Compound;
        uint256 DAI;
    }
    
    constructor() public
    {
        block_start = block.number;
        addMinter(address(this));
        selected_protocol = 3; // No protocol yet
        
        // Fulcrum
        iDAI = iToken(fake);
        cDAI =cToken(fake);
        
        // Approve transfer
        DAI = IERC20(ciao_token); //IERC20(0xaD6D458402F60fD3Bd25163575031ACDce07538D);
        DAI.approve(fake, 2**256 - 1);
    }
    
    function getPoolSize() public view returns (uint256) {
        if(totalSupply() == 0) {
            return 0;
        }
        
        if( selected_protocol == 0) {
            return iDAI.assetBalanceOf(address(this));
        }
        
        if( selected_protocol == 1) {
            cDAI.balanceOf(address(this));
        }
        
        return totalSupply();
    }
    
    function getState() public view returns (State memory){
        State memory current = State(
            iDAI.assetBalanceOf(address(this)),
            cDAI.balanceOf(address(this)),
            DAI.balanceOf(address(this))
        );
        
        return current;
    }
    
    function getTokenPrice() public view returns (uint256){
        if(totalSupply() == 0) {
            return 1;
        }
	    return getPoolSize() / totalSupply();  
    }
    
    function add(uint256 value) public {
        require (value > 0, "value == 0");
        
        uint256 priceToken = getTokenPrice();
        
        require(DAI.transferFrom(msg.sender, address(this), value), "Transfer token not allowed");
        
        // uint256 toBeMinted = value.mul(10**18).div(priceToken);
        uint256 toBeMinted = value / priceToken;
        _mint(msg.sender, toBeMinted);
        
        contributions[msg.sender] = Contribution(value, block.number, msg.sender);
        
        // Mint
        if( selected_protocol == 0) {
            iDAI.mint(address(this), value);
        }
        
        if( selected_protocol == 1) {
            cDAI.mint(value);
        }
    }
    
    function withdraw(uint256 value) public {
        require(value > 0, "value == 0");

        if (value > balanceOf(msg.sender)) {
            value = balanceOf(msg.sender);
        }
        
        uint256 priceToken = getTokenPrice();
        uint256 willWithdraw = value * priceToken;
        
        if( selected_protocol == 0) {
            uint256 iTokenToWithdraw = willWithdraw / iDAI.tokenPrice();
            iDAI.burn(msg.sender, iTokenToWithdraw);
        } else if ( selected_protocol == 1) {
            cDAI.redeemUnderlying(willWithdraw);
        } else {
            require(DAI.transfer(msg.sender, willWithdraw), "withdraw not allowed");    
        }
        
        burn(value);
    }
    
    function()  
        external
        payable
    {
        revert();
    }
    
    
}
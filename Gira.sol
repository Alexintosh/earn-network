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
    function balanceOf(address account) external view returns (uint);
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
    uint256 public selected_protocol; // 0 = Fulcum , 1 = Compound
    
    
    // Tokens
    address cDAI_ropsten = 0xb6b09fBffBa6A5C4631e5F7B2e3Ee183aC259c0d;
    address iDAI_ropsten = 0xFCE3aEeEC8EB39304ED423c0d23c0A978DA9E934;
    address dai_ropsten = 0xaD6D458402F60fD3Bd25163575031ACDce07538D; // Too many dai on ropsten 0x25a01a05C188DaCBCf1D61Af55D4a5B4021F7eeD
    
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
        selected_protocol = 0;
        
        // Fulcrum
        iDAI = iToken(iDAI_ropsten);
        cDAI =cToken(cDAI_ropsten);
        
        // Approve transfer
        DAI = IERC20(dai_ropsten);
        DAI.approve(iDAI_ropsten, 2**256 - 1);
        DAI.approve(cDAI_ropsten, 2**256 - 1);
    }
    
    function changeProtocol(uint256 id) public {
        selected_protocol = id;
    }
    
    function getPoolSize() public view returns (uint256) {
        if(totalSupply() == 0) {
            return 0;
        }
        
        uint balance;
        
        balance += iDAI.assetBalanceOf(address(this));
        balance += cDAI.balanceOf(address(this));
        balance += DAI.balanceOf(address(this));
        
        return balance;
    }
    
    function getState() public view returns (State memory){
        State memory current = State(
            iDAI.assetBalanceOf(address(this)),
            cDAI.balanceOf(address(this)),
            DAI.balanceOf(address(this))
        );
        
        return current;
    }
    
    // https://ethereum.stackexchange.com/questions/15090/cant-do-any-integer-division
    function getTokenPrice() public view returns (uint256){
        if(totalSupply() == 0) {
            return 1;
        }
        
	    return getPoolSize()
                .mul(10**18)
                .div(totalSupply());
    }
    
    function assetBalanceOf(
        address _owner)
        public
        view
        returns (uint256)
    {
        return balanceOf(_owner)
            .mul(getTokenPrice())
            .div(10**18);
    }
    
    function add(uint256 value) public {
        require (value > 0, "value == 0");
        
        uint256 priceToken = getTokenPrice();
        
        require(DAI.transferFrom(msg.sender, address(this), value), "Transfer token not allowed");
        
        uint256 toBeMinted = value.div(priceToken);
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
    
    function simWithdraw(uint256 value) public view returns (uint256, uint256){
        require(value > 0, "value == 0");

        if (value > balanceOf(msg.sender)) {
            value = balanceOf(msg.sender);
        }
        
        uint256 priceToken = getTokenPrice();
        uint256 willWithdraw = value.mul(priceToken).div(10**18);
        return (priceToken, willWithdraw);
    }
    
    
    function iDAIPrice() public view returns (uint256){ 
        return iDAI.tokenPrice();    
    }
    
    function emergency_withdrawiDAI() public {
        uint256 cDaiBalance = cDAI.balanceOf(address(this));
        if( cDaiBalance > 0 ){
            cDAI.redeemUnderlying(cDaiBalance);
        }
        
        uint256 iDaiBalance = iDAI.balanceOf(address(this));
        if( iDaiBalance > 0 ){
            iDAI.burn(address(this), iDaiBalance);
        }
        require(DAI.transfer(msg.sender, DAI.balanceOf(address(this))), "withdraw not allowed");
    }
    
    function withdrawCdai(uint256 balance) public {
        cDAI.redeemUnderlying(balance);
    }
    
    function withdrawIdai(uint256 balance) public {
        iDAI.burn(address(this), balance);
    }
    
    function mintCdai(uint256 balance) public {
        cDAI.mint(balance);
    }
    
    function mintIdai(uint256 balance) public {
        iDAI.mint(address(this), balance);
    }
    
    function balanceIdai() public view returns (uint256){
        return iDAI.balanceOf(address(this));
    }
    
    function rebalanceTo(uint256 id) public returns (uint256) {
     
     //BUG dobbiamo controllar tutti i balance   
        State memory balances = getState();
        // uint256 balanceI = iDAI.balanceOf(address(this));
        // uint256 balanceC = cDAI.balanceOf(address(this));
        // uint256 balanceD = DAI.balanceOf(address(this));
        
        uint256 total = balances.DAI;
        
        if( balances.Compound > 0 ){
            cDAI.redeemUnderlying(balances.Compound);
            total += balances.Compound;
        }
        
        if( balances.Fulcrum > 0 ){
            
            uint idaiBal = balanceIdai();
            iDAI.burn(address(this), idaiBal);
            total += balances.Fulcrum;
        }
        
        if( id == 0 ) {
            iDAI.mint(address(this), total);
        } 
        
        if ( id == 1 ) {
            cDAI.mint(total);
        }
        
        return total;
    }
    
    function withdraw(uint256 value) public {
        require(value > 0, "value == 0");

        if (value > balanceOf(msg.sender)) {
            value = balanceOf(msg.sender);
        }
        
        uint256 priceToken = getTokenPrice();
        uint256 willWithdraw = value.mul(priceToken).div(10**18);
        
        State memory balances = getState();
        
        if( balances.DAI >= willWithdraw ){
            require(DAI.transfer(msg.sender, willWithdraw), "withdraw not allowed");    
            burn(value);
            return;
        }
        
        if( balances.Compound > 0 ){
            cDAI.redeemUnderlying(willWithdraw);
            require(DAI.transfer(msg.sender, willWithdraw), "withdraw not allowed");
            burn(value);
            return;
        }
        
        if( balances.Fulcrum > 0 ){
            iDAI.burn(msg.sender, willWithdraw);
            burn(value);
            return;
        }
        
        // if( selected_protocol == 0) {
        //     iDAI.burn(msg.sender, willWithdraw);
        // } else if ( selected_protocol == 1) {
        //     cDAI.redeemUnderlying(willWithdraw);
        //     require(DAI.transfer(msg.sender, willWithdraw), "withdraw not allowed");
        // } else {
        //     //BUG
        //     require(DAI.transfer(msg.sender, willWithdraw), "withdraw not allowed");    
        // }
        
        // burn(value);
    }
    
    function()  
        external
        payable
    {
        revert();
    }
    
    
}
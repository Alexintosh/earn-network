pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./interfaces/cToken.sol";
import "./interfaces/iToken.sol";


contract Girasol is ERC20, ERC20Detailed, Ownable {

    uint256 public constant INITIAL_SUPPLY = 0 /*0 * (10 ** uint256(decimals))*/;
    uint256 public constant POOLSIZE = 0 /*0 * (10 ** uint256(decimals))*/;
    uint block_start;
    IERC20 DAI;
    iToken iDAI;
    cToken cDAI;
    uint256 public selected_protocol; // 0 = Fulcum , 1 = Compound


    // Tokens
    address public cDAI_ropsten = 0xb6b09fBffBa6A5C4631e5F7B2e3Ee183aC259c0d;
    address public iDAI_ropsten = 0xFCE3aEeEC8EB39304ED423c0d23c0A978DA9E934;
    address public dai_ropsten = 0xaD6D458402F60fD3Bd25163575031ACDce07538D; // Too many dai on ropsten 0x25a01a05C188DaCBCf1D61Af55D4a5B4021F7eeD

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

    constructor() ERC20Detailed("Earn DAI", "eDAI", 18) public
    {
        block_start = block.number;
        selected_protocol = 0;

        // Fulcrum
        iDAI = iToken(iDAI_ropsten);
        cDAI = cToken(cDAI_ropsten);

        // Approve transfer
        DAI = IERC20(dai_ropsten);
        DAI.approve(iDAI_ropsten, 2**256 - 1);
        DAI.approve(cDAI_ropsten, 2**256 - 1);
    }

    function changeProtocol(uint256 id) onlyOwner public {
        require(id == 0 || id == 1, "CAN_NOT_SELECT_NON_EXISTENT_PROTOCOL");
        selected_protocol = id;
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

    // TODO remove this on mainnet
    function emergency_withdrawiDAI() onlyOwner public {
        iDAI.burn(msg.sender, iDAI.assetBalanceOf(address(this)));
        cDAI.redeemUnderlying(cDAI.balanceOf(address(this)));
        require(DAI.transfer(msg.sender, DAI.balanceOf(address(this))), "withdraw not allowed");
    }

    function withdraw(uint256 value) public {
        require(value > 0, "value == 0");

        if (value > balanceOf(msg.sender)) {
            value = balanceOf(msg.sender);
        }

        uint256 priceToken = getTokenPrice();
        uint256 willWithdraw = value.mul(priceToken).div(10**18);

        if( selected_protocol == 0) {
            iDAI.burn(msg.sender, willWithdraw);
        } else if ( selected_protocol == 1) {
            cDAI.redeemUnderlying(willWithdraw);
            require(DAI.transfer(msg.sender, willWithdraw), "withdraw not allowed");
        } else {
            require(DAI.transfer(msg.sender, willWithdraw), "withdraw not allowed");
        }

        _burn(msg.sender, value);
    }

    // Reverting on standard method is standard now
    // function()
    //     external
    //     payable
    // {
    //     revert();
    // }

}
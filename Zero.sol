// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract Zero is IERC20, Ownable {
    using SafeMath for uint;
    IERC20 public tether;
    string private _symbol;
    string private _name;
    uint8 private _decimals;
    uint private _Liquidity; // Tether
    uint private _totalSupply; // ZERO
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) private _allowances;

    constructor() {
        _name = "Zero Token";
        _symbol = "ZERO";
        _decimals = 18;
        _Liquidity = 0;
        _totalSupply = 0;
        tether = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }

    function liquidity() public view returns (uint) {
        return _Liquidity;
    }

    function price() public view returns (uint) {
        uint scaleFactor = 10 ** 18;
        // Use this factor to show decimal
        uint scaledPrice = SafeMath.div(
            SafeMath.mul(SafeMath.mul(_Liquidity, 10 ** 18), scaleFactor),
            SafeMath.mul(_totalSupply, 10 ** 6)
        );
        return scaledPrice;
        // True price is scaledPrice/scaleFactor
    }

    function balanceOf(address account) public view returns (uint) {
        return _balances[account];
    }

    function _approve(address owner, address spender, uint amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint addedValue
    ) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint subtractedValue
    ) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "Decreased allowance below zero"
            )
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint amount
    ) internal {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");

        _balances[sender] = _balances[sender].sub(
            amount,
            "Transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function transfer(address recipient, uint _amount) external returns (bool) {
        require(_balances[_msgSender()] >= _amount, "Insufficient balance.");
        _transfer(_msgSender(), recipient, _amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint _amount
    ) external returns (bool) {
        require(_balances[_msgSender()] >= _amount, "Insufficient balance.");
        _transfer(_msgSender(), recipient, _amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(_amount)
        );
        return true;
    }

    // Buy token = Mint new token
    function buy(address _wallet, uint _amount) external {
        require(_wallet != address(0), "Invalid wallet address");
        require(_amount > 0, "Tether amount should be greater than zero");
        tether.transferFrom(_msgSender(), address(this), _amount);
        mintToken(_wallet, _amount);
    }

    function mintToken(address _address, uint _amount) private {
        // _amount is tether
        uint liquidityFee = SafeMath.div(SafeMath.mul(_amount, 2), 100);
        uint ownerFee = SafeMath.div(SafeMath.mul(_amount, 5), 1000);
        uint remainAmount = SafeMath.sub(
            _amount,
            SafeMath.add(liquidityFee, ownerFee)
        );
        _Liquidity = SafeMath.add(_Liquidity, liquidityFee);
        uint userMintAmount = SafeMath.div(
            SafeMath.mul(remainAmount, _totalSupply),
            _Liquidity
        );
        uint ownerMintAmount = SafeMath.div(
            SafeMath.mul(ownerFee, _totalSupply),
            _Liquidity
        );
        _Liquidity = SafeMath.add(
            _Liquidity,
            SafeMath.add(remainAmount, ownerFee)
        );
        _totalSupply = SafeMath.add(
            _totalSupply,
            SafeMath.add(userMintAmount, ownerMintAmount)
        );
        _balances[_address] = SafeMath.add(_balances[_address], userMintAmount);
        _balances[owner()] = SafeMath.add(_balances[owner()], ownerMintAmount);
        emit Transfer(address(0), _address, userMintAmount);
        emit Transfer(address(0), owner(), ownerMintAmount);
    }

    // Sell token = Burn token
    function sell(uint _amount) external {
        // _amount is ZERO
        require(_msgSender() != address(0), "Burn from the zero address!");
        require(_amount > 0, "Amount should be greater than zero.");
        require(_balances[_msgSender()] >= _amount, "Insufficient balance.");
        emit Transfer(_msgSender(), address(this), _amount);
        _balances[_msgSender()] = _balances[_msgSender()].sub(_amount);
        transferTether(_amount);
        burnToken(_amount);
    }

    // Transfer tether to seller
    function transferTether(uint _amount) private {
        // Calculate the amount of tether to transfer based on the ZERO amount.
        uint tetherAmount = SafeMath.div(
            SafeMath.mul(_amount, _Liquidity),
            _totalSupply
        );
        uint sentAmount = SafeMath.div(SafeMath.mul(tetherAmount, 975), 1000);
        uint ownerAmount = SafeMath.div(SafeMath.mul(tetherAmount, 1), 100);

        // Transfer Tether
        require(tether.transfer(_msgSender(), sentAmount), "Transfer failed");
        require(tether.transfer(owner(), ownerAmount), "Transfer failed");

        // Update the tether liquidity.
        _Liquidity = _Liquidity.sub(
            SafeMath.div(SafeMath.mul(tetherAmount, 985), 1000)
        );
    }

    // Burn seller's tokens
    function burnToken(uint _amount) private {
        // _amount is ZERO
        emit Transfer(address(this), address(0), _amount);
        _totalSupply = _totalSupply.sub(_amount);
    }

    // External add liquidity
    function addLiquidity(uint _amount) external {
        require(_amount > 0, "tether amount should be greater than zero");
        tether.transferFrom(_msgSender(), address(this), _amount);
        if (_totalSupply == 0) {
            _totalSupply = 1000000 * 10 ** _decimals;
            _balances[_msgSender()] = _totalSupply;
            emit Transfer(address(0), _msgSender(), _totalSupply);
        }
        _Liquidity = SafeMath.add(_Liquidity, _amount);
    }
}

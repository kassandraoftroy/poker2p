// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../utils/Ownable.sol";
import "../token/ERC20.sol";
import "../interfaces/ICERC20.sol";

contract Flush is Ownable, ERC20 {
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IERC20 public reserveToken;
    ICERC20 public cReserveToken;
    uint256 public totalReserve;
    uint256 public mintFeeBPS;
    mapping(address => mapping (address => uint256)) withdrawAllowance;

    event Minted(address sender, uint256 amount);
    event Burned(address sender, uint256 amount);
    event WithdrawalApproval(address spender, address token, uint256 amount);

    constructor(
        address _reserveTokenAddress,
        address _cReserveTokenAddress,
        uint256 _mintFeeBPS
    ) ERC20("Flush Token", "FLUSH") {
        reserveToken = IERC20(_reserveTokenAddress);
        cReserveToken = ICERC20(_cReserveTokenAddress);
        mintFeeBPS = _mintFeeBPS;
    }

    function mint(uint256 _amount) public {
        uint256 mintAmount = _amount - ((_amount * mintFeeBPS) / 10000);
        _handleMint(mintAmount);
        require(reserveToken.transferFrom(_msgSender(), address(this), _amount), "mint() ERC20.transferFrom failed.");
        require(reserveToken.approve(address(cReserveToken), _amount), "mint() ERC20.approve failed.");
        require(cReserveToken.mint(_amount) == 0, "mint() cERC20.mint failed.");
        totalReserve = totalReserve + mintAmount;
    }

    function burn(uint256 _amount) public {
        _handleBurn(_amount);
        require(cReserveToken.redeemUnderlying(_amount) == 0, "burn() cERC20.redeemUnderlying failed.");
        require(reserveToken.transfer(_msgSender(), _amount), "burn() ERC20.transfer failed.");
        totalReserve = totalReserve - _amount;
    }

    function increaseWithdrawalApproval(address _to, address _tokenAddress, uint256 _amount) public onlyOwner {
        require(_tokenAddress != address(cReserveToken), "approveWithdrawal() cannot withdraw collateral token.");
        withdrawAllowance[_to][_tokenAddress] = withdrawAllowance[_to][_tokenAddress] + _amount;
        emit WithdrawalApproval(_to, _tokenAddress, withdrawAllowance[_to][_tokenAddress]);
    }

    function decreaseWithdrawalApproval(address _to, address _tokenAddress, uint256 _amount) public onlyOwner {
        require(_tokenAddress != address(cReserveToken), "approveWithdrawal() cannot withdraw collateral token.");
        withdrawAllowance[_to][_tokenAddress] = withdrawAllowance[_to][_tokenAddress] - _amount;
        emit WithdrawalApproval(_to, _tokenAddress, withdrawAllowance[_to][_tokenAddress]);
    }

    function withdrawInterest(uint256 _amount) public {
        if (_msgSender() != owner()) {
            uint256 currentAllowance = withdrawAllowance[_msgSender()][address(reserveToken)];
            require(currentAllowance >= _amount, "withdrawInterest() not enough withdrawAllowance");
            withdrawAllowance[_msgSender()][address(reserveToken)] = currentAllowance - _amount;
            emit WithdrawalApproval(_msgSender(), address(reserveToken), withdrawAllowance[_msgSender()][address(reserveToken)]);
        }
        uint256 interest = reserveDifferential();
        require(interest >= _amount, "withdrawInterest() interest accrued is below withdraw amount");
        require(cReserveToken.redeemUnderlying(_amount) == 0, "withdrawInterest() cERC20.redeemUnderlying failed.");
        require(reserveToken.transfer(_msgSender(), _amount), "withdrawInterest() ERC20.transfer failed.");
    }

    function withdrawToken(address _tokenAddress, uint256 _amount) public {
        require(_tokenAddress != address(cReserveToken), "withdrawToken() cannot withdraw collateral token.");
        if (_msgSender() != owner()) {
            uint256 currentAllowance = withdrawAllowance[_msgSender()][_tokenAddress];
            require(currentAllowance >= _amount, "withdrawInterest() not enough withdrawAllowance");
            withdrawAllowance[_msgSender()][_tokenAddress] = currentAllowance - _amount;
            emit WithdrawalApproval(_msgSender(), _tokenAddress, withdrawAllowance[_msgSender()][_tokenAddress]);
        }
        if (_tokenAddress == ETH) {
            require(address(this).balance >= _amount);
            (bool success, ) = payable(_msgSender()).call{value: _amount}("");
            require(success, "withdrawToken() eth transfer failed");
        } else {
            require(IERC20(_tokenAddress).transfer(_msgSender(), _amount), "withdrawToken() ERC20.transfer failed.");
        }
    }

    function reserveBalance() public view returns (uint256) {
        return totalReserve;
    }

    function reserveDifferential() public view returns (uint256) {
        return cReserveToken.balanceOfUnderlying(address(this)) - totalReserve;
    }

    function _handleMint(uint256 _amount) internal {
        require(_amount > 0, "Deposit must be non-zero.");
        _mint(_msgSender(), _amount);
        emit Minted(_msgSender(), _amount);
    }

    function _handleBurn(uint256 _amount) internal {
        require(_amount > 0, "Amount must be non-zero.");
        require(balanceOf(_msgSender()) >= _amount, "Insufficient tokens to burn.");

        _burn(_msgSender(), _amount);
        emit Burned(_msgSender(), _amount);
    }
}
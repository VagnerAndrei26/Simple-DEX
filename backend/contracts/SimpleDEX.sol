// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleDEX is ERC20 {
    
    address public icoTokenAddress;
    
    constructor(address _icoAddress) ERC20("Lp token" , "LPT") {
        require(_icoAddress != address(0), "Can't provide the 0 address");
        icoTokenAddress = _icoAddress;
    }

    /**
    * @dev Returns the amount of `Crypto Dev Tokens` held by the contract
    */
    function getReserve() public view returns(uint) {
        return ERC20(icoTokenAddress).balanceOf(address(this));
    }

    /**
    * @dev Adds liquidity to the exchange.
    */
    function addLiquidity(uint _amount) public payable returns(uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint icoTokenReserve = getReserve();
        ERC20 icoToken = ERC20(icoTokenAddress);
        /*
        If the reserve is empty, intake any user supplied value for
        `Ether` and `icoToken` tokens because there is no ratio currently
        */
        if(icoTokenReserve == 0) {
            // Transfer the `cryptoDevToken` from the user's account to the contract
            icoToken.transferFrom(msg.sender, address(this), _amount);
            // Take the current ethBalance and mint `ethBalance` amount of LP tokens to the user.
            // `liquidity` provided is equal to `ethBalance` because this is the first time user
            // is adding `Eth` to the contract, so whatever `Eth` contract has is equal to the one supplied
            // by the user in the current `addLiquidity` call
            // `liquidity` tokens that need to be minted to the user on `addLiquidity` call should always be proportional
            // to the Eth specified by the user
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        } else {
            /*
            If the reserve is not empty, intake any user supplied value for
            `Ether` and determine according to the ratio how many `Crypto Dev` tokens
            need to be supplied to prevent any large price impacts because of the additional
            liquidity
            */
            // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user
            // in the current `addLiquidity` call
            uint ethReserve = ethBalance - msg.value;
            // Ratio should always be maintained so that there are no major price impacts when adding liquidity
            // Ratio here is -> (icoTokenAmount user can add/icoTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract);
            // So doing some maths, (icoTokenAmount user can add) = (Eth Sent by the user * icoTokenReserve /Eth Reserve);
            uint icoTokenAmount = (msg.value * icoTokenReserve) /(ethReserve);
            require(_amount >= icoTokenAmount, "Amount of tokens provided is less than the minimum amount required");
            // transfer only (icoTokenAmount user can add) amount of `ICO tokens` from users account
            // to the contract      
             icoToken.transferFrom(msg.sender, address(this), icoTokenAmount);
            // The amount of LP tokens that would be sent to the user should be proportional to the liquidity of
            // ether added by the user
            // Ratio here to be maintained is ->
            // (LP tokens to be sent to the user (liquidity)/ totalSupply of LP tokens in contract) = (Eth sent by the user)/(Eth reserve in the contract)
            // by some maths -> liquidity =  (totalSupply of LP tokens in contract * (Eth sent by the user))/(Eth reserve in the contract)  
            liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
            }
            return liquidity;
    }

    /**
    * @dev Returns the amount Eth/Crypto Dev tokens that would be returned to the user
    * in the swap
    */
    function removeLiquidity(uint _amount) public returns(uint, uint){
        require(_amount > 0 , "Amount should be greater than 0");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();
         // The amount of Eth that would be sent back to the user is based
        // on a ratio
        // Ratio is -> (Eth sent back to the user) / (current Eth reserve)
        // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // Then by some maths -> (Eth sent back to the user)
        // = (current Eth reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint ethAmount = (ethReserve * _amount) / _totalSupply;
        uint icoTokenAmount =(getReserve() * _amount) / _totalSupply;
        // Burn the sent LP tokens from the user's wallet because they are already sent to
        // remove liquidity
        _burn(msg.sender, _amount);
        // Transfer `ethAmount` of Eth from the contract to the user's wallet
        (bool s, ) = payable(msg.sender).call{ value:ethAmount }("");
        require(s, "Transfer not succesfull");
        // Transfer `icoTokensAmount` of ICO tokens from the contract to the user's wallet
        ERC20(icoTokenAddress).transfer(msg.sender,icoTokenAmount);
        return (ethAmount, icoTokenAmount);
    }

    /**
    * @dev Returns the amount Eth/ICO tokens that would be returned to the user
    * in the swap
    */
    function getAmountTokens(
        uint inputAmount,
        uint inputReserve,
        uint outputReserve
    ) public pure returns(uint) {
        require(inputReserve > 0 && outputReserve > 0 ,"no liquidity in the pool");
        // We are charging a fee of `1%`
        // Input amount with fee = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100
        uint inputAmountWithFees = inputAmount * 99;
        // Because we need to follow the concept of `XY = K` curve
        // We need to make sure (x + Δx) * (y - Δy) = x * y
        // So the final formula is Δy = (y * Δx) / (x + Δx)
        // Δy in our case is `tokens to be received`
        // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
        // So by putting the values in the formulae you can get the numerator and denominator
        uint numerator = inputAmountWithFees * outputReserve;
        uint denominator = (inputReserve * 100) + inputAmountWithFees;
        return numerator / denominator;
    }


    /**
    * @dev Swaps Eth for CryptoDev Tokens
    */
    function ethtoIcoToken(uint _minTokens) public payable {
        uint tokenReserve = getReserve();
        // call the `getAmountOfTokens` to get the amount of ICO tokens
        // that would be returned to the user after the swap
        // Notice that the `inputReserve` we are sending is equal to
        // `address(this).balance - msg.value` instead of just `address(this).balance`
        // because `address(this).balance` already contains the `msg.value` user has sent in the given call
        // so we need to subtract it to get the actual input reserve
        uint tokensBought = getAmountTokens(msg.value, address(this).balance - msg.value, tokenReserve);
        require(tokensBought >= _minTokens, "Insufficient output amount");
        // Transfer ICO token to user
        ERC20(icoTokenAddress).transfer(msg.sender, tokensBought);
    }

    /**
    * @dev Swaps CryptoDev Tokens for Eth
    */
    function icoTokenToEth(uint _tokenSold, uint _minEth) public {
        uint tokenReserve = getReserve();
        uint ethReserve = address(this).balance;

        uint ethBought = getAmountTokens(_tokenSold, tokenReserve, ethReserve);
        require(ethBought >= _minEth, "Inssuficient output amount");
        ERC20(icoTokenAddress).transferFrom(msg.sender, address(this), _tokenSold);
        //Transfer ether
        (bool s, ) = payable(msg.sender).call{ value: ethBought }("");
        require(s, "Transfer failed");
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract TestTimeLock {
    address public timeLock;
    
    constructor(address _timeLock) {
        timeLock = _timeLock;
    }

    function test() external view{
        require(msg.sender == timeLock, "Callee is not timeLock contract");
    }

    function getTimeStamp() external view returns(uint256){
        return block.timestamp + 100;
    }
}
//SPDX-License-Identifier:MIT

pragma solidity 0.8.27;

import {TimelockController} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

contract TimeLock is TimelockController {
    //minDelay is how long you have to wait for executing
    //proposers is the list of addresses that can propose
    //executers is the list of addresses that can execute
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executers)
        TimelockController(minDelay, proposers, executers, msg.sender)
    {}
}

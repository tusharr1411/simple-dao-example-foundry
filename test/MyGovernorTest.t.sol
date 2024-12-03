//SPDX-License-Identifier:MIT

pragma solidity 0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {Box} from "../src/Box.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
    Box box;
    GovernanceToken governanceToken;
    MyGovernor myGovernor;
    TimeLock timeLock;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes, you have 1 hour before you can enact
    uint256 public constant VOTING_DELAY = 1; // after how many block the voting will start after the proposal creation
    uint256 public constant QUORUM_PERCENTAGE = 4; // Need 4% of voters to pass
    uint256 public constant VOTING_PERIOD = 50400; // This is how long voting lasts

    address[] public proposers;
    address[] public executors;

    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        governanceToken = new GovernanceToken();
        governanceToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        governanceToken.delegate(USER);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        myGovernor = new MyGovernor(governanceToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(myGovernor));
        timeLock.grantRole(executorRole, (address(0)));
        timeLock.revokeRole(adminRole, USER);

        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function test_CanNotUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(123);
    }

    function test_GovernanceUpdatesTheBox() public {
        uint256 valueToStore = 1411;

        string memory description = "hey ! lets vote to update the box number to 888";
        bytes memory dataToCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);

        calldatas.push(dataToCall);
        targets.push(address(box));

        // propose this to the DAO

        uint256 proposalId = myGovernor.propose(targets, values, calldatas, description);

        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        // vote for the proposal
        string memory reason = "cuz i like 1411";
        uint8 voteType = 1; // for == yes;

        vm.prank(USER);
        myGovernor.castVoteWithReason(proposalId, voteType, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        // queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);
        vm.roll(block.number + MIN_DELAY + 1);
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // 4. Execute
        myGovernor.execute(targets, values, calldatas, descriptionHash);

        console.log("Box Number: ", box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
}

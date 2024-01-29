//SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    /*Events */
    event EnteredLottery(address indexed player);
    Lottery lottery;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkTokenAddress;
    // uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployLottery deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            linkTokenAddress,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testInitalizesInOpenState() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    //  EnterLottery
    function testLotteryRevertsWhenDoNotPayEnough() public {
        //Arrange
        // uint256 amountEntered = 0.001 ether;
        vm.prank(PLAYER);
        //Act//Assert
        vm.expectRevert(Lottery.Lottery__NotEnoughMoneySent.selector);

        // lottery.enterLottery{value: amountEntered}();
        lottery.enterLottery();
    }

    function testLotteryRecordsPlayerWhenTheyEnter() public {
        //Arrange
        // uint256 amountEntered = 0.01 ether;
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        //Assert
        assert(lottery.getPlayers(0) == PLAYER);
    }

    function testEmitEventsOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }

    function testCantEnterWhenLotteryIsCalculating() public {
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.enterLottery{value: entranceFee}();

        lottery.performUpkeep("");
        vm.expectRevert(Lottery.Lottery_LotteryStateNotOpen.selector);
        lottery.enterLottery{value: entranceFee}();
    }

    //checkup keep test

    function testCheckupReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        //assert

        assert(!upkeepNeeded);
    }

    function testCheckupReturnsFalseIfLotteryStateIsNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.enterLottery{value: entranceFee}();
        lottery.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        //Arrange
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        lottery.enterLottery{value: entranceFee}();

        //Act
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        //Arrange
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.enterLottery{value: entranceFee}();
        // lottery.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        //assert
        assert(upkeepNeeded);
    }

    //Performupkeep test
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
    }

    function testPerformUpkeepRevertsWhenCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = address(lottery).balance;
        uint256 numOfPlayers = 0;
        uint256 lotteryState = 0;

        console.log(
            "This is the current balance of the lottery contract: ",
            currentBalance
        );

        //Assert / Act
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__UpkeepNotUpdated.selector,
                currentBalance,
                numOfPlayers,
                lotteryState
            )
        );
        lottery.performUpkeep("");
    }

    modifier lotteryEnteredAndTimePassed() {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //What if I need to test using the output of an event
    function testPerformUpkeepUpdatedLotteryStateAndEmitRequestId()
        public
        lotteryEnteredAndTimePassed
    {
        //Act
        vm.recordLogs();
        lottery.performUpkeep(""); //emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Lottery.LotteryState lState = lottery.getLotteryState();

        assert(uint256(requestId) > 0);
        assert(uint256(lState) == 1);
    }

    //FulfillRandomWords

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public lotteryEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function testFulfillRandomPicksAWinnerAndSendsMoney()
        public
        lotteryEnteredAndTimePassed
        skipFork
    {
        //Arrange

        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < additionalEntrants + startingIndex;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            lottery.enterLottery{value: entranceFee}();
        }

        //Acc
        uint256 prize = entranceFee * (additionalEntrants + 1);
        uint256 previousTimeStamp = lottery.getLastTimeStamp();
        vm.recordLogs();
        lottery.performUpkeep(""); //emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //We need to be pretend to be a Chainlink VRF to get a random number and pick a winner
        // vm.recordLogs();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );

        // Vm.Log[] memory pickedEntries = vm.getRecordedLogs();
        // bytes32 winner = pickedEntries[0].topics[1];
        // console.log("This is it: ", uint256(winner));

        assert(uint256(lottery.getLotteryState()) == 0);
        assert(lottery.getRecentWinner() != address(0));
        assert(lottery.getNumOfPlayers() == 0);
        assert(lottery.getLastTimeStamp() > previousTimeStamp);
        assert(
            lottery.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entranceFee
        );
        // assert(uint256(winner) > 0);
    }
}

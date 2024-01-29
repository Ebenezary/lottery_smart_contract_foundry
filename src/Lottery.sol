// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A contract for Raffle /Lottery
 * @author GEO
 * @notice This contract is to showcase untamperable decentralized lottery smart contract
 * @dev This makes use of chainlink VRF V2 and chainlink keeper
 */

contract Lottery is VRFConsumerBaseV2 {
    /**Errors */
    error Lottery__NotEnoughMoneySent();
    error Lottery__TransferFailed();
    error Lottery_LotteryStateNotOpen();
    error Lottery__UpkeepNotUpdated(
        uint256 currentBalance,
        uint256 numOfPlayers,
        uint256 lotteryState
    );

    /**Type Declaration */
    enum LotteryState {
        OPEN, // 0 ==> During this time, players are allowed to still enter the lottery
        CALCULATING //1 ==> During this time, no one is allowed to enter the lottery, as it is time for a winner to be picked
    }

    /**State Variable */
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //==> Duration of the lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    LotteryState private s_lotteryState;

    /**Events */
    event EnteredLottery(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedLotteryWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryState.OPEN;
    }

    function enterLottery() external payable {
        // require(msg.value >= i_entranceFee, "NOT ENOUGH MONEY SENT"); ==> Require function is not gas efficent, instead we use the custom error below
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughMoneySent();
        }

        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery_LotteryStateNotOpen();
        }
        s_players.push(payable(msg.sender));

        //The two main reasons for event
        //1. Makes migration easier
        //2. Makes front end "Indexing" easier
        emit EnteredLottery(msg.sender);
    }

    /**
     * @dev This is the function the chainlink keeeper node call
     * they look for the `upkeepNeeded` to return true
     * The  following should be true in order to return true
     * 1. Our interval should have passed
     * 2. There should be at least 1 player, and should have ETH for gas
     * 3. Our subscripttion is funded with LINK
     * 4. The lottery should be in an `OPEN` state
     */

    function checkUpkeep(
        bytes memory /*callData*/
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = LotteryState.OPEN == s_lotteryState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    //1.Get a ramdom number
    //2. Use the random number to pick a player
    //3. Be authomatically called
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotUpdated(
                address(this).balance,
                s_players.length,
                uint256(s_lotteryState)
            );
        }

        //This function was initially pickWinner, it is a manual call, but there is a need to automate it. Hence, why we made use of the Chainlink Automation.

        //To pick a winner, we can check if enough time is passed

        //If it passes through the above stage, it definitely means we are about to pick random number

        //Chainlink VRF is two transactions
        //1. request thne RNG
        //2. Get the Random Number

        s_lotteryState = LotteryState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedLotteryWinner(requestId);
    }

    //CEI: Checks, effects, Interactions

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] memory randomWords
    ) internal override {
        //We can finally pick our random winner using a Modulo function
        //Checks
        //Effect(Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_lotteryState = LotteryState.OPEN;
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        //Interactions(other contracts)
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Lottery__TransferFailed();
        }
    }

    /** Getter Function */

    function getEngranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getLotteryState() external view returns (LotteryState) {
        return s_lotteryState;
    }

    function getPlayers(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getNumOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}

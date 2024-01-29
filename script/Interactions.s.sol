//SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.t.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function CreateSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscrptionId on: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Yout subId is :", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return CreateSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant AMOUNT = 3 ether;

    function fundSubscriptionConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkTokenAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        fundSubscription(
            vrfCoordinator,
            subscriptionId,
            linkTokenAddress,
            deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address linkTokenAddress,
        uint256 deployerKey
    ) public {
        console.log("Funding suscription subId: ", subscriptionId);
        console.log("Using VRFCoordinator: ", vrfCoordinator);
        console.log("On chainId: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(linkTokenAddress).transferAndCall(
                vrfCoordinator,
                AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address lotteryContractAddress,
        address vrfCoordinator,
        uint64 subscriptionId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", lotteryContractAddress);
        console.log("Using VRFCoordinator: ", vrfCoordinator);
        console.log("On chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            lotteryContractAddress
        );
        vm.stopBroadcast();
    }

    function addCosumerUsingConfig(address lotteryContractAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(
            lotteryContractAddress,
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );
    }

    function run() external {
        address lotteryContractAddress = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );
        addCosumerUsingConfig(lotteryContractAddress);
    }
}

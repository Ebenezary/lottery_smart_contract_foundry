## Lottery Smart contract

## About

This code is created to be embedded with a random smart contract lottert

## What we would like it to do ?

1. Users can enter into the lottery by paying for a ticket
   1. All the ticket fee will be going to the winner immediately after the draw.
2. After Y stipulated time, the lottery smart contract will authomatically draw a winner
   1. This will be definitely be drawn programmatically
3. The Random selection of winners will be possible by the use of the Chainlink VRF and Chainlink Authomation
   1. Chainlink VRF -> Randomness
   2. Chainlink Automation -> Time Based Trigger

## Tests

1. Write some deploy scripts
2. Write our test
   1. Work on local chain
   2. Forked Test
   3. Forked Mainnet

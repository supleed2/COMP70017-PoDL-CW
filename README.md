# Coursework skeleton

This is the skeleton for the coursework of the Principle of Distributed Ledgers 2023.
It contains [the interfaces](./src/interfaces) of the contracts to implement and an [ERC20 implementation](./src/contracts/PurchaseToken.sol).

The repository uses [Foundry](https://book.getfoundry.sh/projects/working-on-an-existing-project).

Coverage generated using `rm -rf coverage/* && forge coverage --report lcov && genhtml lcov.info -o coverage --branch-coverage --function-coverage --legend --title "TicketNFT Coverage" && rm lcov.info`

`TicketNFT` coverage report is located [here](./coverage/src/contracts/TicketNFT.sol.gcov.html). Coverage for the `TicketNFT` contract is:

| Statistic | Hit | Total |     % |
| --------- | --- | ----- | ----- |
| Lines     |  71 |    71 | 100.0 |
| Functions |  14 |    14 | 100.0 |
| Branches  |  52 |    52 | 100.0 |

Primary Market Limit test uses a foundry cheat code to set the `totalSupply` storage cell to 999, followed by a successful and then a failing purchase.

default: build

build:
	@forge build

test:
	@forge test

# Target for formatting the contract's code.
format:
	@forge fmt
	@echo "Formatting complete."

# Target for generating a gas report.
gas:
	@forge test --gas-report

# Target for flattening the contract.
flatten:
	@forge flatten src/p2peth.sol

# Target for creating a gas usage snapshot.
gas-snap:
	@forge snapshot
	@echo "Gas snapshot created. Check generated .gas-snapshot."

.PHONY: build test format gas flatten gas-snap


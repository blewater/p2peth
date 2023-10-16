default: build

build:
	@forge build

clean-build:
	@forge clean
	@forge build

test:
	@forge test

# deploy to Anvil
deploy:
	@curl -s -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' > /dev/null || (echo "Start Anvil first in a different terminal pane" && exit 1)
	@forge script script/p2peth.s.sol:P2pEthScript --rpc-url http://127.0.0.1:8545 --broadcast

# Format the contract's code.
format:
	@forge fmt
	@echo "Formatting complete."

# Generate a gas report.
gas:
	@forge test --gas-report

# Flatten the contract.
flatten:
	@forge flatten src/p2peth.sol

# Create a gas usage snapshot.
gas-snap:
	@forge snapshot
	@echo "Gas snapshot created. Check generated .gas-snapshot."

anvil:
	@anvil

# Ask Anvil's account 0 contract balance from the site
balance:
	@curl "http://localhost:8080/users/0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266/balance"

# Deposit amount to account 0's contract to the site
# e.g., `make deposit amount=1`
deposit:
	@curl -X POST http://localhost:8080/users/deposit/$(amount) -H "Content-Type: application/json" -d '{}'	

.PHONY: build clean-build test format gas flatten gas-snap anvil balance deposit


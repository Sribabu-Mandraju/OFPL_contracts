include .env

# -----------------------------
# Config
# -----------------------------
RPC_URL ?= http://127.0.0.1:8545
PRIVATE_KEY ?= 0xYOUR_PRIVATE_KEY
SCRIPT ?= script/GiveLoan.s.sol:GiveLoan

# -----------------------------
# Default
# -----------------------------
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make build        - Compile contracts"
	@echo "  make test         - Run tests"
	@echo "  make test-gas     - Run tests with gas report"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make fmt          - Format contracts"
	@echo "  make anvil        - Start local anvil node"
	@echo "  make script       - Run script (dry run)"
	@echo "  make script-live  - Broadcast script"
	@echo "  make coverage     - Run coverage"

# -----------------------------
# Build & Test
# -----------------------------
.PHONY: build
build:
	forge build

.PHONY: test
test:
	forge test -vv

.PHONY: test-gas
test-gas:
	forge test --gas-report

.PHONY: coverage
coverage:
	forge coverage

.PHONY: clean
clean:
	forge clean

.PHONY: fmt
fmt:
	forge fmt

# -----------------------------
# Local Chain
# -----------------------------
.PHONY: anvil
anvil:
	anvil

# -----------------------------
# Scripts
# -----------------------------
.PHONY: script
script:
	forge script $(SCRIPT) \
		--rpc-url $(RPC_URL) \
		-vvv

.PHONY: script-live
script-live:
	forge script $(SCRIPT) \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--private-key $(PRIVATE_KEY) \
		-vvv


deploy: 
	@forge script script/Deploy.s.sol --rpc-url https://base-sepolia.g.alchemy.com/v2/GQXyK5v1cXTXl5Ub0idAE --private-key $(ADMIN_PRIVATE_KEY) --broadcast -vvvv

add-allowed-token: 
	@forge script script/AddAllowedToken.s.sol:AddAllowedToken --rpc-url https://base-sepolia.g.alchemy.com/v2/GQXyK5v1cXTXl5Ub0idAE --private-key $(ADMIN_PRIVATE_KEY) --broadcast -vvvv

create-pool:
	@forge script script/createPool.s.sol:CreatePool --rpc-url https://base-sepolia.g.alchemy.com/v2/GQXyK5v1cXTXl5Ub0idAE --private-key $(ADMIN_PRIVATE_KEY) --broadcast -vvvv

take-loan:
	@forge script script/createPool.s.sol:TakeLoan --rpc-url https://base-sepolia.g.alchemy.com/v2/GQXyK5v1cXTXl5Ub0idAE --private-key $(LOAN_TAKER_PRIVATE_KEY) --broadcast -vvvv


create-another-pool:
	@forge script script/createPool.s.sol:CreatePool --rpc-url https://base-sepolia.g.alchemy.com/v2/GQXyK5v1cXTXl5Ub0idAE --private-key $(LOAN_TAKER_PRIVATE_KEY) --broadcast -vvvv

give-loan:
	@forge script script/createPool.s.sol:GiveLoan --rpc-url https://base-sepolia.g.alchemy.com/v2/GQXyK5v1cXTXl5Ub0idAE --private-key $(ADMIN_PRIVATE_KEY) --broadcast -vvvv
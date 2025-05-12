//
pragma solidity 0.8.29;

import {VaultBridgeToken, ILxLyBridge} from "../../VaultBridgeToken.sol";
import {IWETH9} from "../../etc/IWETH9.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IVersioned} from "../../etc/IVersioned.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vault Bridge gas token
/// @dev CAUTION! As-is, this contract MUST NOT be used on a network if the gas token is not ETH.
contract VbETH is VaultBridgeToken {
    using SafeERC20 for IWETH9;

    error ContractNotSupportedOnThisNetwork();
    error InsufficientMessageValue(uint256 messageValue, uint256 requiredValue);

    constructor() {
        _disableInitializers();
    }

    function initialize(address initializer_, VaultBridgeToken.InitializationParameters calldata initParams)
        external
        initializer
    {
        require(
            ILxLyBridge(initParams.lxlyBridge).gasTokenAddress() == address(0)
                && ILxLyBridge(initParams.lxlyBridge).gasTokenNetwork() == 0,
            ContractNotSupportedOnThisNetwork()
        );

        // Initialize the base implementation.
        __VaultBridgeToken_init(initializer_, initParams);
    }

    /// @dev deposit ETH to get vbETH
    function depositGasToken(address receiver) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        (shares,) = _deposit(msg.value, lxlyId(), receiver, false, 0);
    }

    /// @dev deposit ETH to get vbETH and bridge to an L2
    function depositGasTokenAndBridge(
        address destinationAddress,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        (shares,) = _deposit(msg.value, destinationNetworkId, destinationAddress, forceUpdateGlobalExitRoot, 0);
    }

    function mintWithGasToken(uint256 shares, address receiver)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, InvalidShares());
        // The receiver is checked in the `_deposit` function.

        // Mint vbToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) =
        // msg.value is used as assets value, if it exceeds shares value, WETH will be refunded
         _deposit(msg.value, lxlyId(), receiver, false, shares);

        // Check the output.
        require(mintedShares == shares, IncorrectAmountOfSharesMinted(mintedShares, shares));
    }

    function _receiveUnderlyingToken(address, uint256 assets) internal override {
        IWETH9 weth = IWETH9(address(underlyingToken()));

        if (msg.value > 0) {
            require(msg.value >= assets, InsufficientMessageValue(msg.value, assets));
            // deposit everything, excess funds will be refunded in WETH
            weth.deposit{value: msg.value}();
        } else {
            weth.safeTransferFrom(msg.sender, address(this), assets);
        }
    }

    /// @inheritdoc IVersioned
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
}

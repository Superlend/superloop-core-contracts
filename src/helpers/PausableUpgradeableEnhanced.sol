// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @dev An enhanced PausableUpgradeable contract from openzeppelin that allows for freezing of the contract
 * User operations are not allowed when paused
 * User + Vault operator operations are not allowed when frozen
 */
abstract contract PausableUpgradeableEnhanced is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Pausable
    struct PausableStorage {
        bool _paused;
        bool _frozen;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Pausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PausableStorageLocation =
        0xcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300;

    function _getPausableStorage() private pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PausableStorageLocation
        }
    }

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev Emitted when the freeze is triggered by `account`.
     */
    event Frozen(address account);

    /**
     * @dev Emitted when the freeze is lifted by `account`.
     */
    event Unfrozen(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev The operation failed because the contract is frozen.
     */
    error EnforcedFrozen();

    /**
     * @dev The operation failed because the contract is not frozen.
     */
    error ExpectedFrozen();

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenNotFrozen() {
        _requireNotFrozen();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    modifier whenFrozen() {
        _requireFrozen();
        _;
    }

    function __PausableUpgradeableEnhanced_init() internal onlyInitializing {}

    function __PausableUpgradeableEnhanced_init_unchained() internal onlyInitializing {}
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */

    function paused() public view virtual returns (bool) {
        PausableStorage storage $ = _getPausableStorage();
        return $._paused;
    }

    function frozen() public view virtual returns (bool) {
        PausableStorage storage $ = _getPausableStorage();
        return $._frozen;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requireNotFrozen() internal view virtual {
        if (frozen()) {
            revert EnforcedFrozen();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    function _requireFrozen() internal view virtual {
        if (!frozen()) {
            revert ExpectedFrozen();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = true;
        emit Paused(_msgSender());
    }

    function _freeze() internal virtual whenNotFrozen {
        PausableStorage storage $ = _getPausableStorage();
        $._frozen = true;

        if (!paused()) _pause();

        emit Frozen(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused and not frozen.
     */
    function _unpause() internal virtual whenPaused whenNotFrozen {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
        emit Unpaused(_msgSender());
    }

    function _unfreeze() internal virtual whenFrozen {
        PausableStorage storage $ = _getPausableStorage();
        $._frozen = false;

        emit Unfrozen(_msgSender());
    }
}

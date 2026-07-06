// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ========================= AgoraOwnable2Step ========================
// ====================================================================

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

struct ConstructorParams {
    address ownerAddress;
}

/// @title AgoraOwnable2Step
/// @dev Inspired by FraxFinance's Timelock2Step contract
/// @notice  An abstract contract which adds internal functions for access control (modifiers are an anti-pattern as used in Ownable)
contract AgoraOwnable2Step is Ownable2Step {
    constructor(ConstructorParams memory _params) Ownable(_params.ownerAddress) {}

    // ============================================================================================
    // Functions: Internal Checks
    // ============================================================================================

    /// @notice The ```_isOwner``` function checks if _address is current owner address
    /// @param _address The address to check against the owner
    /// @return Whether or not msg.sender is current owner address
    function _isOwner(address _address) internal view returns (bool) {
        return _address == owner();
    }

    /// @notice The ```_requireIsOwner``` function reverts if _address is not current owner address
    /// @param _address The address to check against the owner
    function _requireIsOwner(address _address) internal view {
        if (!_isOwner(_address)) revert AddressIsNotOwner({ ownerAddress: owner(), actualAddress: _address });
    }

    /// @notice The ```_requireSenderIsOwner``` function reverts if msg.sender is not current owner address
    /// @dev This function is to be implemented by a public function
    function _requireSenderIsOwner() internal view {
        _requireIsOwner({ _address: msg.sender });
    }

    /// @notice The ```_isPendingOwner``` function checks if the _address is pending owner address
    /// @dev This function is to be implemented by a public function
    /// @param _address The address to check against the pending owner
    /// @return Whether or not _address is pending owner address
    function _isPendingOwner(address _address) internal view returns (bool) {
        return _address == pendingOwner();
    }

    /// @notice The ```_requireIsPendingOwner``` function reverts if the _address is not pending owner address
    /// @dev This function is to be implemented by a public function
    /// @param _address The address to check against the pending owner
    function _requireIsPendingOwner(address _address) internal view {
        if (!_isPendingOwner({ _address: _address })) {
            revert AddressIsNotPendingOwner({ pendingOwnerAddress: pendingOwner(), actualAddress: _address });
        }
    }

    /// @notice The ```_requirePendingOwner``` function reverts if msg.sender is not pending owner address
    /// @dev This function is to be implemented by a public function
    function _requireSenderIsPendingOwner() internal view {
        _requireIsPendingOwner({ _address: msg.sender });
    }

    // ============================================================================================
    // Functions: Errors
    // ============================================================================================

    /// @notice Emitted when owner is transferred
    error AddressIsNotOwner(address ownerAddress, address actualAddress);

    /// @notice Emitted when pending owner is transferred
    error AddressIsNotPendingOwner(address pendingOwnerAddress, address actualAddress);
}

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
// ========================= AgoraPrivilegedRole ======================
// ====================================================================

import { ConstructorParams as OwnableAccessControlParams, OwnableAccessControl } from "./OwnableAccessControl.sol";

import { IAgoraDollar } from "interfaces/IAgoraDollar.sol";
import { IAgoraProxyAdmin } from "interfaces/IAgoraProxyAdmin.sol";

struct ConstructorParams {
    address ownerAddress;
    address agoraDollarAddress;
    address agoraDollarProxyAdminAddress;
}

contract AgoraPrivilegedRole is OwnableAccessControl {
    IAgoraDollar public immutable agoraDollar;
    IAgoraProxyAdmin public immutable agoraDollarProxyAdmin;

    constructor(
        ConstructorParams memory _params
    ) OwnableAccessControl(OwnableAccessControlParams({ ownerAddress: _params.ownerAddress })) {
        agoraDollar = IAgoraDollar(_params.agoraDollarAddress);
        agoraDollarProxyAdmin = IAgoraProxyAdmin(_params.agoraDollarProxyAdminAddress);
    }

    //==============================================================================
    // AcceptRole Functions
    //==============================================================================

    function acceptTransferRole(bytes32 _roleId) external {
        _requireSenderIsOwner();
        agoraDollar.acceptTransferRole({ _role: _roleId });
    }

    function transferRole(bytes32 _roleId, address _newAddress) external {
        _requireSenderIsOwner();
        agoraDollar.transferRole({ _role: _roleId, _newAddress: _newAddress });
    }

    //==============================================================================
    // Minter Role Functions
    //==============================================================================

    struct MintInfo {
        uint256 amount;
        uint256 timestamp;
    }

    struct MintThrottleInfo {
        uint256 maxMintAmount;
        uint256 mintWindow;
    }

    mapping(address _minter => MintInfo[] _mints) public historicalMints;
    mapping(address _minter => MintThrottleInfo _minterThrottleInfo) public minterThrottles;

    function setMinterThrottleInfo(address _minter, uint256 _maxMintAmount, uint256 _mintWindow) external {
        _requireSenderIsOwner();
        minterThrottles[_minter] = MintThrottleInfo({ maxMintAmount: _maxMintAmount, mintWindow: _mintWindow });
        emit SetMinterThrottleInfo({ minter: _minter, maxMintAmount: _maxMintAmount, mintWindow: _mintWindow });
    }

    function batchMint(IAgoraDollar.BatchMintParam[] memory _mints) public {
        // Checks: ensure sender has the authority to call this function
        _requireIsRole(msg.sender);

        // Checks: ensure new mint amount does not exceed threshold
        MintThrottleInfo memory _minterThrottleInfo = minterThrottles[msg.sender];
        uint256 _totalMintAmount = 0;
        for (uint256 i = 0; i < _mints.length; i++) {
            _totalMintAmount += _mints[i].value;
        }
        if (
            getSumOfMints({ _account: msg.sender, _window: _minterThrottleInfo.mintWindow }) + _totalMintAmount >
            _minterThrottleInfo.maxMintAmount
        ) revert MintAmountExceedsThrottle();

        // Effects: keep track of historical mints
        historicalMints[msg.sender].push(MintInfo({ amount: _totalMintAmount, timestamp: block.timestamp }));
        // Interactions: call mint function on AgoraDollar
        agoraDollar.batchMint(_mints);
    }

    function mint(address _receiverAddress, uint256 _value) external {
        IAgoraDollar.BatchMintParam[] memory _mints = new IAgoraDollar.BatchMintParam[](1);
        _mints[0] = IAgoraDollar.BatchMintParam({ receiverAddress: _receiverAddress, value: _value });
        batchMint(_mints);
    }

    function getSumOfMints(address _account, uint256 _window) public view returns (uint256 _sum) {
        uint256 _windowStart = block.timestamp - _window;
        uint256 _length = historicalMints[_account].length;
        if (_length == 0) return 0;
        for (uint256 i = _length; i > 0; i--) {
            uint256 _index = i - 1;
            if (historicalMints[_account][_index].timestamp >= _windowStart) {
                _sum += historicalMints[_account][_index].amount;
            } else {
                break;
            }
        }
    }

    //==============================================================================
    // Burner Role Functions
    //==============================================================================

    function batchBurnFrom(IAgoraDollar.BatchBurnFromParam[] memory _burns) public {
        _requireIsRole(msg.sender);
        agoraDollar.batchBurnFrom(_burns);
    }

    function burnFrom(address _burnFormAddress, uint256 _value) external {
        IAgoraDollar.BatchBurnFromParam[] memory _burns = new IAgoraDollar.BatchBurnFromParam[](1);
        _burns[0] = IAgoraDollar.BatchBurnFromParam({ burnFromAddress: _burnFormAddress, value: _value });
        batchBurnFrom(_burns);
    }

    //==============================================================================
    // Freezer Role Functions
    //==============================================================================

    function freezeAccount(address _account) external {
        _requireIsRole(msg.sender);
        agoraDollar.freeze(_account);
    }

    function unfreezeAccount(address _account) external {
        _requireIsRole(msg.sender);
        agoraDollar.unfreeze(_account);
    }

    //==============================================================================
    // Pauser Role Functions
    //==============================================================================

    function setIsMintPaused(bool _isPaused) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsMintPaused(_isPaused);
    }

    function setIsBurnFromPaused(bool _isPaused) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsBurnFromPaused(_isPaused);
    }

    function setIsFreezingPaused(bool _isPaused) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsFreezingPaused(_isPaused);
    }

    function setIsTransferPaused(bool _isPaused) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsTransferPaused(_isPaused);
    }

    function setIsSignatureVerificationPaused(bool _isPaused) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsSignatureVerificationPaused(_isPaused);
    }

    //==============================================================================
    // Admin Functions
    //==============================================================================

    function upgradeToAndCall(address _newImplementation, bytes memory _data) external {
        _requireIsRole(msg.sender);
        agoraDollarProxyAdmin.upgradeAndCall({
            proxy: address(agoraDollar),
            implementation: _newImplementation,
            data: _data
        });
    }

    function proxyAdminTransferOwnership(address _newAdmin) external {
        _requireIsRole(msg.sender);
        agoraDollarProxyAdmin.transferOwnership(_newAdmin);
    }

    function proxyAdminAcceptOwnership() external {
        _requireIsRole(msg.sender);
        agoraDollarProxyAdmin.acceptOwnership();
    }

    function setIsMsgSenderCheckEnabled(bool _isEnabled) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsMsgSenderCheckEnabled(_isEnabled);
    }

    function setIsReceiveWithAuthorizationUpgraded(bool _isUpgraded) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsReceiveWithAuthorizationUpgraded(_isUpgraded);
    }

    function setIsTransferUpgraded(bool _isUpgraded) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsTransferUpgraded(_isUpgraded);
    }

    function setIsTransferWithAuthorizationUpgraded(bool _isUpgraded) external {
        _requireIsRole(msg.sender);
        agoraDollar.setIsTransferWithAuthorizationUpgraded(_isUpgraded);
    }

    //==============================================================================
    // Events
    //==============================================================================

    event SetMinterThrottleInfo(address minter, uint256 maxMintAmount, uint256 mintWindow);

    //==============================================================================
    // Errors
    //==============================================================================

    error MintAmountExceedsThrottle();
}

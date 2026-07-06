// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { AgoraPrivilegedRole, ConstructorParams } from "contracts/AgoraPrivilegedRole.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployPrivilegedRole is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        AgoraPrivilegedRole role = new AgoraPrivilegedRole(
            ConstructorParams({
                ownerAddress: deployer,
                agoraDollarAddress: deployer, // mock — no real AUSD on local
                agoraDollarProxyAdminAddress: deployer // mock — proves F1: this is IGNORED
            })
        );

        console.log("Deployed to:         ", address(role));
        console.log("agoraDollar:         ", address(role.agoraDollar()));
        console.log("agoraDollarProxyAdmin:", address(role.agoraDollarProxyAdmin()));
        console.log("owner:               ", role.owner());

        vm.stopBroadcast();
    }
}

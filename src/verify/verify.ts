import { spawn } from "child_process";
import { createPublicClient, http, parseAbi } from "viem";
import { anvil } from "viem/chains";
import { readFileSync } from "fs";

const RPC_URL = "http://127.0.0.1:8545";

const CONTRACT_ABI = parseAbi([
  "function agoraDollarProxyAdmin() view returns (address)",
  "function agoraDollar() view returns (address)",
  "function owner() view returns (address)",
]);

const DEPLOYER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const ZERO_ADDR = "0x0000000000000000000000000000000000000000";

const DEPLOY_PRIVILIGED_ROLE_SOLIDITY = "src/script/DeployPrivilegedRole.s.sol:DeployPrivilegedRole";
const PRIVATE_KEY_FORGE = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const LATEST_BROADCAST_PATH = "broadcast/DeployPrivilegedRole.s.sol/31337/run-latest.json";

async function main() {
  const stopAnvil = startAnvil();
  let allPassed = false;

  try {
    const client = await waitForAnvil();
    await runForgeScript();
    console.log("contract deployed");

    const contractAddress = getContractAddress();
    console.log({ contractAddress });

    // TODO: double-check this later
    // @ts-expect-error viem 2.54 bug: authorizationList incorrectly required in ReadContractParameters
    const proxyAdmin = await client.readContract({
      address: contractAddress as `0x${string}`,
      abi: CONTRACT_ABI,
      functionName: "agoraDollarProxyAdmin",
    });
    console.log("agoraDollarProxyAdmin:", proxyAdmin);

    // @ts-expect-error viem 2.54 bug: authorizationList incorrectly required in ReadContractParameters
    const agoraDollar = await client.readContract({
      address: contractAddress as `0x${string}`,
      abi: CONTRACT_ABI,
      functionName: "agoraDollar",
    });
    console.log("agoraDollar:", agoraDollar);

    // @ts-expect-error viem 2.54 bug: authorizationList incorrectly required in ReadContractParameters
    const owner = await client.readContract({
      address: contractAddress as `0x${string}`,
      abi: CONTRACT_ABI,
      functionName: "owner",
    });
    console.log("owner:", owner);

    const checks = [
      {
        name: "#1 - agoraDollar set correctly",
        expected: DEPLOYER,
        actual: agoraDollar,
        pass: agoraDollar === DEPLOYER,
      },
      {
        name: "#2 - agoraDollarProxyAdmin not zero",
        expected: "non-zero",
        actual: proxyAdmin,
        pass: proxyAdmin !== ZERO_ADDR,
      },
      {
        name: "#3 - owner set correctly",
        expected: DEPLOYER,
        actual: owner,
        pass: owner === DEPLOYER,
      },
    ];

    allPassed = checks.every((c) => c.pass);
    const report = {
      contract: "AgoraPrivilegedRole",
      deployedAt: contractAddress,
      checks,
      allPassed,
    };

    if (!allPassed) {
      console.error(JSON.stringify(report, null, 2));
    }
  } finally {
    stopAnvil();
  }

  if (!allPassed) {
    process.exit(1);
  }

  console.log("All Passed");
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});

// Start anvil as a child process. Returns a cleanup function.
function startAnvil(): () => void {
  const anvilProcess = spawn("anvil", [], {
    stdio: "pipe", // suppress anvil output
  });

  anvilProcess.on("error", (err) => {
    console.error("Failed to start anvil:", err.message);
    process.exit(1);
  });

  return () => anvilProcess.kill();
}

// Poll the RPC until anvil is ready. Retries up to maxAttempts times.
async function waitForAnvil(maxAttempts = 20) {
  const client = createPublicClient({ chain: anvil, transport: http(RPC_URL) });

  for (let i = 0; i < maxAttempts; i++) {
    try {
      const chainId = await client.getChainId();
      console.log("anvil ready — chain ID:", chainId);
      return client;
    } catch {
      await new Promise((r) => setTimeout(r, 250)); // wait 250ms, try again
    }
  }

  throw new Error("anvil did not become ready in time");
}

// Deploy the contract via forge script. Writes broadcast JSON to disk.
function runForgeScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    const forge = spawn("forge", ["script", DEPLOY_PRIVILIGED_ROLE_SOLIDITY, "--rpc-url", RPC_URL, "--broadcast"], {
      stdio: "pipe",
      env: {
        ...process.env,
        PRIVATE_KEY: PRIVATE_KEY_FORGE,
      },
    });

    forge.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`forge script failed with exit code ${code}`));
    });

    forge.on("error", (err) => {
      reject(new Error(`Failed to start forge: ${err.message}`));
    });
  });
}

function getContractAddress(): string {
  const rawBroadcast = readFileSync(LATEST_BROADCAST_PATH, "utf8");
  const json = JSON.parse(rawBroadcast);
  const contractAddress = json.transactions[0].contractAddress;
  return contractAddress;
}

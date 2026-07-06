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

async function main() {
  const stopAnvil = startAnvil();

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
  } finally {
    stopAnvil();
  }
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
    const forge = spawn(
      "forge",
      ["script", "src/script/DeployPrivilegedRole.s.sol:DeployPrivilegedRole", "--rpc-url", RPC_URL, "--broadcast"],
      {
        stdio: "pipe",
        env: {
          ...process.env,
          PRIVATE_KEY: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        },
      },
    );

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
  const rawBroadcast = readFileSync("broadcast/DeployPrivilegedRole.s.sol/31337/run-latest.json", "utf8");
  const json = JSON.parse(rawBroadcast);
  const contractAddress = json.transactions[0].contractAddress;
  return contractAddress;
}

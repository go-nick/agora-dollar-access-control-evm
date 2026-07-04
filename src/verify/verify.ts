import { spawn } from "child_process";
import { createPublicClient, http } from "viem";

const RPC_URL = "http://127.0.0.1:8545";

async function main() {
  const stopAnvil = startAnvil();

  try {
    await waitForAnvil();

    const client = createPublicClient({ transport: http(RPC_URL) });
    const chainId = await client.getChainId();
    console.log("anvil ready — chain ID:", chainId);

    await runForgeScript();
    console.log("contract deployed");
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
  const anvil = spawn("anvil", [], {
    stdio: "pipe", // suppress anvil output
  });

  anvil.on("error", (err) => {
    console.error("Failed to start anvil:", err.message);
    process.exit(1);
  });

  return () => anvil.kill();
}

// Poll the RPC until anvil is ready. Retries up to maxAttempts times.
async function waitForAnvil(maxAttempts = 20): Promise<void> {
  const client = createPublicClient({ transport: http(RPC_URL) });

  for (let i = 0; i < maxAttempts; i++) {
    try {
      await client.getChainId();
      return; // success
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

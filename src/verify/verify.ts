import { spawn } from "child_process";
import { createPublicClient, http } from "viem";

const RPC_URL = "http://127.0.0.1:8545";

// Start anvil as a child process. Returns a cleanup function.
function startAnvil(): () => void {
  const anvil = spawn("anvil", [], {
    stdio: "pipe", // suppress anvil output — we don't need it in verify
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

async function main() {
  const stopAnvil = startAnvil();

  try {
    await waitForAnvil();

    const client = createPublicClient({ transport: http(RPC_URL) });
    const chainId = await client.getChainId();

    console.log("anvil ready — chain ID:", chainId);
    console.log({ client });
    // expected: 31337
  } finally {
    stopAnvil();
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});

import { type Denovo } from "https://deno.land/x/denovo_core@v0.0.6/mod.ts";
import { join } from "https://deno.land/std@0.171.0/path/mod.ts";
import { assertString } from "https://deno.land/x/unknownutil@v2.1.0/assert.ts";

export function main(denovo: Denovo): Promise<void> {
  denovo.dispatcher = {
    complete(cwd: string, lbuffer: string) {
      return complete(denovo, cwd, lbuffer);
    },
  };
  return Promise.resolve();
}

async function complete(
  denovo: Denovo,
  cwd: string,
  lbuffer: string,
): Promise<void> {
  const capture = join(denovo.directory, "bin", "capture.zsh");
  const command = new Deno.Command(
    "zsh",
    {
      args: [capture, lbuffer],
      cwd: cwd,
    },
  );

  const { stdout } = await command.output();

  const items = new TextDecoder().decode(stdout).trim().split(/\r?\n/)
    .filter((line) => line.length !== 0)
    .map((line) => {
      const pieces = line.split(" -- ");
      return pieces.length <= 1 ? line : pieces[0];
    });

  const selection = await denovo.dispatch("denovo-fzf", "fzf", ...[
    ...new Set(items),
  ]);
  assertString(selection);
  if (selection === "") {
    return;
  }

  const words = lbuffer.split(/\s/);
  words.pop();

  const newLBuffer = JSON.stringify(
    `${words.join(" ")} ${selection.trim()}`.trim(),
  );
  console.log(newLBuffer);

  await denovo.eval(`LBUFFER=${newLBuffer}`);
}

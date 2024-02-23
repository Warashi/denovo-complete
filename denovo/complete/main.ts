import { type Denovo } from "https://deno.land/x/denovo_core@v0.0.7/mod.ts";
import { join } from "https://deno.land/std@0.216.0/path/mod.ts";
import { assert, is } from "https://deno.land/x/unknownutil@v3.16.3/mod.ts";

export function main(denovo: Denovo): void {
  denovo.dispatcher = {
    complete() {
      return complete(denovo);
    },
  };
}

async function complete(
  denovo: Denovo,
): Promise<void> {
  const [cwd, lbuffer, ...fpath] = (await denovo.eval(
    `_v=("$PWD" "$LBUFFER" $fpath[@]); print -rNC1 -- "$_v[@]"; unset _v;`,
  )).split("\0");
  const capture = join(denovo.directory, "bin", "capture.zsh");
  const command = new Deno.Command(
    "zsh",
    {
      args: [capture, lbuffer],
      cwd: cwd,
      env: {
        FPATH: fpath
          .filter((s) => s.length > 0)
          .join(":"),
      },
    },
  );

  const { stdout } = await command.output();

  const items = new TextDecoder().decode(stdout).trim().split(/\r?\n/)
    .filter((line) => line.length !== 0);

  const selection = await denovo.dispatch(
    "fzf",
    "fzf-with-options",
    ...[
      [
        `--delimiter='\\0'`,
        `--with-nth=1`,
        `--preview='echo {2}'`,
      ].join(" "),
      ...new Set(items),
    ],
  );
  assert(selection, is.String);
  if (selection.trim() === "") {
    return;
  }
  const pieces = selection.trim().split("\0");
  const newWord = pieces.length < 1 ? selection.trim() : pieces[0].trim();

  const words = lbuffer.split(/\s/);
  words.pop();

  const newLBuffer = `${words.join(" ")} ${newWord}`
    .trim()
    .replaceAll(`"`, `\\"`)
    .replaceAll("$", "\\$");

  await denovo.eval(`LBUFFER="${newLBuffer}"`);
}

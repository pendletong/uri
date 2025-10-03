import { run, bench, boxplot, summary } from "mitata";
import { parse } from "../build/dev/javascript/gluri/gluri.mjs";
import { parse as parse2 } from "../build/dev/javascript/gleam_stdlib/gleam/uri.mjs";

bench("parse", () =>
  parse(
    "https://test_name:user%20$$$@github.com/gleam-lang/stdlib/issues/523#issuecomment-3288230480",
  ),
);
bench("parse2", () =>
  parse2(
    "https://test_name:user%20$$$@github.com/gleam-lang/stdlib/issues/523#issuecomment-3288230480",
  ),
);

await run();

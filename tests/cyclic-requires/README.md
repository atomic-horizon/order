# Cyclic require tests

A small test place for Order's hybrid cyclic require handling (`Settings.NativeCyclicRequires`). It contains only the framework, a set of fixture modules that require each other in cycles, and a runner that checks each case on the server and the client.

Most cases use Luau's `export` syntax, so they need the **Luau Modularity** beta enabled in Studio (Beta Features). Without it, those fixtures fail to parse and their cases report FAIL.

## Running

1. From the repository root, build the place:

   ```sh
   rojo build tests/cyclic-requires/cyclic-requires.project.json -o CyclicRequireTests.rbxl
   ```

2. Open `CyclicRequireTests.rbxl` in Studio with Luau Modularity enabled and press Play.
3. Read the Output. Each context prints one line per case and a summary such as `[CyclicRequireTests] [Server] 8/8 passed`. Failures are printed as warnings with the reason.

The runner switches `Settings.NativeCyclicRequires` per case, so the setting in `Settings.luau` doesn't need to change.

## Cases

| # | Setting | Cycle | Expected |
| --- | --- | --- | --- |
| 1 | Off | `return` and `return` | Order's placeholder, same as 3.1.0 |
| 2 | Off | `export` and `export` | Order's placeholder |
| 3 | On | `export` and `export` on one thread | Luau's export table, the same table `shared()` returns, frozen |
| 4 | On | `return` module first, then `export` | Falls back to Order's placeholder, both modules load |
| 5 | On | `export` module first, then `return` | Both modules load (reports which kind of table was handed out) |
| 6 | On | `export` modules on separate task threads | Order's placeholder, no hang (5 second timeout) |
| 7 | On | Top-level read of a native cyclic module | Luau raises an error, reads inside functions work |
| 8 | On | Write to a frozen module through a placeholder | Order warns that exported values are read-only, no error |

The cyclic analysis report labels (`native` / `placeholder`) are not covered here, because the report prints during framework startup. To check them, put a cycle in a real task folder and turn on `Settings.Debug.CyclicAnalysis`.

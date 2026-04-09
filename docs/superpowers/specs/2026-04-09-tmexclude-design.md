# tmexclude Command Design

Date: 2026-04-09

## Overview

A zsh function that recursively excludes folders from Time Machine backups using `tmutil addexclusion`. Useful for excluding dependency directories (node_modules), caches, and build artifacts that don't need backup.

## Function Signature

```zsh
tmexclude [-d|--dry-run] <base-path> <folder-name>
```

## Usage Examples

```zsh
tmexclude ~/projects node_modules          # Exclude all node_modules under ~/projects
tmexclude -d ~ "Caches"                    # Dry-run: show what would be excluded
tmexclude ~/work .git                      # Exclude all .git folders under ~/work
```

## Validation Logic

The function validates input in this order:

1. **Check `tmutil` exists** — `tmutil` is a macOS-only tool. If missing, print error and return 1.
2. **Check argument count** — Expect 2 positional args when not using dry-run, or 2 args plus optional flag.
3. **Check path exists** — Verify `<base-path>` is a valid directory. If not, print error and return 1.
4. **Check folder name is non-empty** — Reject empty folder names.

## Execution Flow

1. **Find matching directories** — Use `find "$base_path" -type d -name "$folder_name" -prune` to locate all folders matching the name under the base path. `-prune` prevents descending into already-matched directories.

2. **Handle no matches** — If `find` returns nothing, print "No folders found" and return 0 (not an error, just nothing to do).

3. **Dry-run mode** — If `-d` or `--dry-run` flag is set, print each discovered path with "Would exclude:" prefix, then return 0 without invoking `tmutil`.

4. **Apply exclusions** — Iterate through discovered directories:
   - Run `sudo tmutil addexclusion "$folder"`
   - Print "Excluding: $folder" after each success
   - If `sudo` fails, print error for that specific folder and continue (don't fail the whole batch)

5. **Summary** — After all exclusions, print "Excluded N folders" to confirm completion.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `tmutil` not found | Error: "tmutil not found. This command requires macOS." |
| Wrong arg count | Usage: `tmexclude [-d\|--dry-run] <base-path> <folder-name>` |
| Base path doesn't exist | Error: "Path does not exist: /path" |
| Base path is not a directory | Error: "Not a directory: /path" |
| Empty folder name | Error: "Folder name cannot be empty" |
| `sudo` fails on one folder | Warn: "Failed to exclude: /path/to/folder" (continue others) |
| `sudo` fails on all folders | Return 1 after processing all |

## Return Codes

- `0` — Success, dry-run completed, or no folders found
- `1` — Validation error or all exclusions failed

## Location

Add to `functions/functions.zsh` following the pattern of existing utilities like `switchphp`, `up`, and `tt`.

## Notes

- Uses `sudo` because `tmutil addexclusion` requires elevated privileges
- `-prune` in the find command prevents redundant work (e.g., excluding nested node_modules inside an already-excluded node_modules)
- Per-folder output matches the existing `switchphp` and `up` patterns in the codebase

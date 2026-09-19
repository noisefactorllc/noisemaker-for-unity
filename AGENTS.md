# Noisemaker for Unity

Unity HLSL and C# integration for the Noisemaker shader platform.

## Strict Rules

HARD, PERMANENT, INVIOLABLE BAN: BANNED FROM SYMLINKS. Never create, introduce, or use symbolic links anywhere in checkouts, repositories, configuration, scripts, or documentation. All files must be regular files. Zero exceptions.

HARD, PERMANENT, INVIOLABLE BAN: Research documents must be written and presented strictly in the established technical whitepaper style. Banned from slop headlines, promotional/slogan headers, parenthetical subtitles in titles, stat cards, metric cards, decorative callouts, marketing-speak, and invented report layouts. Zero exceptions.

## Testing & Build

- **Unit tests**: `python3 -m unittest discover -s parity/tests`
- **Compiler parity tests**: `dotnet run --project tools/compiler-contract-tests` (uses system `dotnet` or Unity's bundled `DotNetSdk/dotnet`)

- **Definitions conversion**: `NM_REFERENCE_ROOT=/path/to/noisemaker node tools/convert-definitions.mjs`

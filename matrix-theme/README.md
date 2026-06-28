# matrix.theme.sh

A Matrix "digital rain" theme for [oh-my-bash](https://github.com/ohmybash/oh-my-bash). Green-on-dark, half-width katakana rain in the header, and a blue-pill / red-pill prompt marker.

![matrix theme screenshot](screenshot/matrix.png)

```
[ ｱｷﾒﾜﾕ ] [ user@host ] [ ~ ] [ ::git ✓ ] [ 01:39:58 ]
💊 › your command here
```

- **Line 1:** bold neon katakana rain · `user@host` · path · git branch with `✓`/`✗` · clock
- **Line 2:** the pill is **blue** normally, flips **red** with the exit code (`›1`) when the last command failed — the blue-pill / red-pill reference. Typed input is dim green.
- Colors: neon (`46`) → medium (`40`) → dim (`34`) → dark (`22`) Matrix greens.
- Ships matching `LS_COLORS` / `EZA_COLORS` palettes and uses [`eza`](https://github.com/eza-community/eza) for colored listings if it's installed (falls back to plain `ls` silently).

## Install

Requires oh-my-bash and **bash 4+**.

```bash
git clone git@github.com:ross-ethridge/matrix-theme.git
cd matrix-theme
./install.sh
```

Then set the theme in your `~/.bashrc`:

```bash
OSH_THEME="matrix"
```

and reload: `source ~/.bashrc`.

The installer just copies `matrix.theme.sh` into `${OSH:-~/.oh-my-bash}/custom/themes/matrix/`. You can also do it by hand.

## macOS notes

The theme is pure bash + ANSI and runs fine on macOS, but:

- **Use Homebrew bash, not the system one.** macOS ships bash 3.2 (2007); oh-my-bash wants 4+.
  ```bash
  brew install bash
  echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells   # /usr/local on Intel
  chsh -s /opt/homebrew/bin/bash
  ```
- **`.bash_profile` vs `.bashrc`** — Terminal/iTerm open *login* shells, which read `~/.bash_profile`, not `~/.bashrc`. Add to `~/.bash_profile`:
  ```bash
  [[ -r ~/.bashrc ]] && source ~/.bashrc
  ```
- **The pill color** relies on the terminal honoring an ANSI color + `U+FE0E` text-presentation selector on the 💊 emoji. Linux VTE terminals (Ptyxis/GNOME) do this. macOS Apple Color Emoji does **not** — Terminal.app/iTerm2 bake the pill's gold/red colors in and ignore ANSI. The theme detects macOS (`$OSTYPE`) and adapts: the pill keeps its native colors and the blue/red success/error signal is carried by the `›` arrow instead.
- `eza` via `brew install eza`.

## License

MIT — see [LICENSE](LICENSE).

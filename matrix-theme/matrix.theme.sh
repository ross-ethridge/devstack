#! bash oh-my-bash.module
#
# matrix - oh-my-bash theme
# "Wake up, Neo..."
# Digital rain color scheme: green on dark

# 256-color Matrix greens
_matrix_bright='\[\e[38;5;46m\]'    # neon green    - primary info
_matrix_mid='\[\e[38;5;40m\]'       # medium green  - secondary info
_matrix_dim='\[\e[38;5;34m\]'       # standard green - structure/brackets
_matrix_dark='\[\e[38;5;22m\]'      # shadow green  - decorators/connectors
_matrix_reset='\[\e[0m\]'
_matrix_blue='\[\e[38;5;33m\]'      # blue pill  - git clean
_matrix_red='\[\e[38;5;196m\]'      # red pill   - git dirty

# SCM prompt styling
SCM_THEME_PROMPT_PREFIX="::"
SCM_THEME_PROMPT_SUFFIX=""
SCM_THEME_PROMPT_DIRTY=" ✗"
SCM_THEME_PROMPT_CLEAN=" ✓"

GIT_THEME_PROMPT_DIRTY=" ✗"
GIT_THEME_PROMPT_CLEAN=" ✓"
GIT_THEME_PROMPT_PREFIX="::"
GIT_THEME_PROMPT_SUFFIX=""

RVM_THEME_PROMPT_PREFIX=""   ; RVM_THEME_PROMPT_SUFFIX=""
RBENV_THEME_PROMPT_PREFIX="" ; RBENV_THEME_PROMPT_SUFFIX=""
RBFU_THEME_PROMPT_PREFIX=""  ; RBFU_THEME_PROMPT_SUFFIX=""

# LS_COLORS: Matrix green palette (fallback for standard ls)
export LS_COLORS='fi=38;5;22:di=38;5;34:ln=38;5;46:so=38;5;34:pi=38;5;22:ex=38;5;46;1:bd=38;5;22;1:cd=38;5;22;1:or=38;5;196:mi=38;5;22;3:*.tar=38;5;34:*.tgz=38;5;34:*.gz=38;5;34:*.bz2=38;5;34:*.zip=38;5;34:*.7z=38;5;34'

# EZA_COLORS: full Matrix green palette including metadata columns
export EZA_COLORS="\
fi=38;5;22:\
di=38;5;34:\
ex=38;5;46;1:\
ln=38;5;46:\
or=38;5;196:\
da=38;5;22:\
sn=38;5;40:\
sb=38;5;34:\
uu=38;5;46:\
un=38;5;34:\
gu=38;5;40:\
gn=38;5;34:\
lc=38;5;22:\
ur=38;5;34:\
uw=38;5;40:\
ux=38;5;46:\
ue=38;5;46:\
gr=38;5;22:\
gw=38;5;22:\
gx=38;5;34:\
tr=38;5;22:\
tw=38;5;22:\
tx=38;5;22:\
xa=38;5;34:\
mp=38;5;40:\
co=38;5;34:\
do=38;5;40:\
lo=38;5;22:\
cm=38;5;46;1:\
hf=38;5;22:\
hd=38;5;22"


# Half-width katakana + digits — the character set used in the movie's digital rain
_matrix_rain_chars=(
  ｦ ｧ ｨ ｩ ｪ ｫ ｬ ｭ ｮ ｯ ｱ ｲ ｳ ｴ ｵ
  ｶ ｷ ｸ ｹ ｺ ｻ ｼ ｽ ｾ ｿ ﾀ ﾁ ﾂ ﾃ ﾄ
  ﾅ ﾆ ﾇ ﾈ ﾉ ﾊ ﾋ ﾌ ﾍ ﾎ ﾏ ﾐ ﾑ ﾒ ﾓ
  ﾔ ﾕ ﾖ ﾗ ﾘ ﾙ ﾚ ﾛ ﾜ ﾝ
  0 1 2 3 4 5 6 7 8 9
)

function _matrix_rain() {
  local n=${1:-8} i s=""
  for ((i = 0; i < n; i++)); do
    s+="${_matrix_rain_chars[RANDOM % ${#_matrix_rain_chars[@]}]}"
  done
  printf "%s" "$s"
}

function _omb_theme_PROMPT_COMMAND() {
  local exitcode=$?
  local scm
  scm="$(scm_prompt_info)"

  # line 1: [ rain ] [ user@host ] [ path ] [ git ] [ time ]
  PS1="\n${_matrix_dim}[ \[\e[1;38;5;46m\]$(_matrix_rain 6)${_matrix_dim} ]"
  PS1+=" [ ${_matrix_mid}\u${_matrix_dark}@${_matrix_mid}\h${_matrix_dim} ]"
  PS1+=" [ ${_matrix_bright}\w${_matrix_dim} ]"

  if [[ -n "$scm" ]]; then
    local git_color
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      git_color="$_matrix_red"
    else
      git_color="$_matrix_blue"
    fi
    PS1+=" ${git_color}[ ${scm}${git_color} ]${_matrix_dim}"
  fi

  PS1+=" [ ${_matrix_dark}$(date +%H:%M:%S)${_matrix_dim} ]"

  # line 2: pill ›  — blue normally, red (+exitcode) on failure.
  # Trailing dim green => dim-green typed input.
  # Uses the Nerd Font "pill" icon (nf-md-pill, U+F0402) rather than the
  # Unicode 💊 emoji: emoji are rendered via color fonts (Segoe UI Emoji,
  # Apple Color Emoji, Noto Color Emoji) whose glyph colors are baked into
  # the font and ignore ANSI SGR — on every terminal, not just some. A Nerd
  # Font icon is a plain vector glyph, so it recolors correctly everywhere.
  # Verified against CaskaydiaCoveNerdFont's actual cmap (glyph name
  # "md-pill" at this codepoint) — a single diagonal capsule, closest
  # monochrome match to the blue-pill/red-pill reference.
  # Requires a Nerd Font to be installed and selected in the terminal.
  local glyph=$'\Uf0402'
  if ((exitcode == 0)); then
    PS1+=$'\n\[\e[38;5;33m\]'"${glyph}"'\[\e[0m\] \[\e[38;5;46m\]› \[\e[38;5;34m\]'
  else
    PS1+=$'\n\[\e[38;5;196m\]'"${glyph}"'\[\e[0m\] \[\e[38;5;196m\]›'"${exitcode}"' \[\e[38;5;34m\]'
  fi
}

_omb_util_add_prompt_command _omb_theme_PROMPT_COMMAND

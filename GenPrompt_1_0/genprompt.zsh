#!/usr/bin/env zsh
# ──────────────────────────────────────────────
# GenPrompt 1.0  –  Multi-model prompt generator (GPT-4o, DALL·E, Sora)
# Pure Zsh, interactive CLI. No Bash-only syntax.
# Author: You (powered by ChatGPT)
# ──────────────────────────────────────────────

set -euo pipefail

# Paths
GENPROMPT_HOME=${GENPROMPT_HOME:-"$HOME/GenPrompt_1_0"}
BANK_DIR="$GENPROMPT_HOME/prompt_banks"
LOG_DIR="$GENPROMPT_HOME/prompt_logs"
mkdir -p "$BANK_DIR" "$LOG_DIR"

# Categories — must match your .txt files (in prompt_banks)
categories=(subjects actions settings times moods styles shots movements)

# Check bank files exist
for cat in $categories; do
  file="$BANK_DIR/${cat}.txt"
  [[ -f "$file" ]] || {
    echo "❌  Missing bank file: $file" >&2
    echo "    Create it or copy the template before running." >&2
    exit 1
  }
done

# Zsh-native bank loader: no Bash-isms
# For each bank, creates two arrays: ${name}_opts and ${name}_desc
load_bank() {
  local name="$1" line opt desc
  eval "${name}_opts=()"
  eval "${name}_desc=()"
  while IFS='|' read -r opt desc || [[ -n "$opt" ]]; do
    # Remove leading/trailing whitespace
    opt="${opt#"${opt%%[![:space:]]*}"}"
    opt="${opt%"${opt##*[![:space:]]}"}"
    desc="${desc#"${desc%%[![:space:]]*}"}"
    desc="${desc%"${desc##*[![:space:]]}"}"
    [[ -z "$opt" || "$opt" == \#* ]] && continue
    eval "${name}_opts+=('\$opt')"
    eval "${name}_desc+=('\${desc:-No description}')"
  done < "$BANK_DIR/${name}.txt"
}

for cat in $categories; do load_bank "$cat"; done

# Interactive picker — no Bash features, all Zsh
pick() {
  local cat="$1" opts desc choice sel
  eval "opts=(\"\${${cat}_opts[@]}\")"
  eval "desc=(\"\${${cat}_desc[@]}\")"
  echo "\n\033[1mSelect $cat:\033[0m"
  echo "0)  (custom $cat)"
  for i in {1..${#opts[@]}}; do
    printf '%-3d %s  —  %s\n' "$i)" "${opts[$i]}" "${desc[$i]}"
  done
  while true; do
    printf "Choice [0-%d]: " "${#opts[@]}"
    read choice
    [[ -z "$choice" ]] && continue
    if [[ "$choice" =~ '^[0-9]+$' ]]; then
      if (( choice==0 )); then
        echo -n "  → Enter custom $cat: "
        read sel; sel="${sel#"${sel%%[![:space:]]*}"}"; sel="${sel%"${sel##*[![:space:]]}"}"
        [[ -z "$sel" ]] && continue
        break
      elif (( choice>=1 && choice<=${#opts[@]} )); then
        sel="${opts[$choice]}"; break
      fi
    fi
    echo "  Invalid choice."
  done
  echo "$sel"
}

# Get user selections interactively
subject=$(pick subjects)
action=$(pick actions)
setting=$(pick settings)
time_lit=$(pick times)
mood=$(pick moods)
style=$(pick styles)
shot=$(pick shots)
movement=$(pick movements)

# Helpers for English articles (a/an)
article_for() {
  [[ "$1" =~ ^[aeiouAEIOU] ]] && echo "an" || echo "a"
}

# Grammar: subject/setting phrases
subject_phrase=$subject
[[ ! "$subject" =~ ^(A |An |The |a |an |the ) ]] && \
  subject_phrase="$(article_for "$subject") $subject"

case "$setting" in
  (in |on |at |under |inside |outside)*|"") setting_phrase="$setting" ;;
  ([A-Z]*)                                  setting_phrase="in $setting" ;;
  (*)                                       setting_phrase="in $(article_for "$setting") $setting" ;;
esac

[[ -n "$time_lit" && ! "$time_lit" =~ ^(in|at|on|during|under) ]] && \
  time_lit="at $time_lit"

style_clause="in $(article_for "$style") $style style"
shot_lc="${shot:l}"
[[ "$movement" == "No movement" || "$movement" == "Static camera" ]] && movement=""

# Model prompts
gpt3_prompt="Research and present concise bullet-point background on $subject (include relevant context about $setting)."
gpt4_prompt="Write a vivid storyline where $subject_phrase $action $setting_phrase $time_lit. Maintain a $mood mood throughout."
dalle_prompt="$subject $action $setting_phrase $time_lit, $style_clause, conveying a $mood mood."
sora_prompt="A $shot_lc of $subject $action $setting_phrase $time_lit. ${movement:+The camera $movement. }The atmosphere is $mood."

# Print nicely
print_prompt_block() {
  print -P "%F{240}──────────────────────────────%f"
  print -P "%B$1%B"
  print "$2"
}

print_prompt_block "GPT-3.5 RESEARCH"  "$gpt3_prompt"
print_prompt_block "GPT-4o STORYLINE"  "$gpt4_prompt"
print_prompt_block "DALL·E IMAGE"      "$dalle_prompt"
print_prompt_block "SORA VIDEO"        "$sora_prompt"

# Clipboard copy (mac: pbcopy, Linux: xclip or wl-copy)
clipboard_block="$(
cat <<EOF
✳ GPT-3.5:
$gpt3_prompt

✳ GPT-4o:
$gpt4_prompt

✳ DALL·E:
$dalle_prompt

✳ Sora:
$sora_prompt
EOF
)"

copy_to_clip() {
  if command -v pbcopy >/dev/null;      then print -rn -- "$clipboard_block" | pbcopy
  elif command -v xclip >/dev/null;     then print -rn -- "$clipboard_block" | xclip -selection clipboard
  elif command -v wl-copy >/dev/null;   then print -rn -- "$clipboard_block" | wl-copy
  else                                  return 1
  fi
}

if copy_to_clip; then
  print -P "%F{32}📋 Prompts copied to clipboard%f"
else
  print -P "%F{33}⚠️  Clipboard tool not found; prompts not copied%f"
fi

# Log to ~/GenPrompt_1_0/prompt_logs/
log_file="$LOG_DIR/$(date +%F).log"
{
  print "────────── $(date '+%Y-%m-%d %H:%M:%S') ──────────"
  print "Subject:   $subject"
  print "Action:    $action"
  print "Setting:   $setting"
  print "Time:      $time_lit"
  print "Mood:      $mood"
  print "Style:     $style"
  print "Shot:      $shot"
  print "Movement:  ${movement:-Static}"
  print ""
  print "$clipboard_block"
  print ""
} >> "$log_file"
print -P "%F{240}🗄  Logged to $log_file%f"

# Placeholder for modcheck integration
# Uncomment below to enable moderation lo

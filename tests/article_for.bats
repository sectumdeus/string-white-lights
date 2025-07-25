#!/usr/bin/env bats

setup() {
  script_dir="$(dirname "$BATS_TEST_DIRNAME")"
  export GENPROMPT_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$GENPROMPT_HOME/prompt_banks" "$GENPROMPT_HOME/prompt_logs"
  for f in subjects actions settings times moods styles shots movements; do
    touch "$GENPROMPT_HOME/prompt_banks/$f.txt"
  done
}

@test "article_for handles words starting with vowel" {
  run zsh -c 'export GENPROMPT_TESTING=1; source "$1"; article_for apple' _ "$script_dir/GenPrompt_1_0/genprompt.zsh"
  [ "$status" -eq 0 ]
  [ "$output" = "an" ]
}

@test "article_for handles words starting with consonant" {
  run zsh -c 'export GENPROMPT_TESTING=1; source "$1"; article_for car' _ "$script_dir/GenPrompt_1_0/genprompt.zsh"
  [ "$status" -eq 0 ]
  [ "$output" = "a" ]
}

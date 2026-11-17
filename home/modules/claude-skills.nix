# Declarative install of Claude Code agent skills, equivalent to:
#   npx -y skills add longbridge/gpui-component --skill gpui-kit --agent claude-code
#   npx -y skills add longbridge/gpui-component --skill gpui-kit-design-guides --agent claude-code
# Pinned to a commit so the skill content only changes when this file is
# bumped, rather than silently drifting on every rebuild.
{ pkgs, ... }:

let
  gpuiComponent = pkgs.fetchFromGitHub {
    owner = "longbridge";
    repo = "gpui-component";
    rev = "5bece8fc054c92c60a083fbf6df25bd11c6025d1";
    sha256 = "0nqswf360raj71bf6dqy5fmi97lv084gbagi46s6mjc4m4lfqbaf";
  };
in
{
  home.file.".claude/skills/gpui-kit".source = "${gpuiComponent}/skills/gpui-kit";
  home.file.".claude/skills/gpui-kit-design-guides".source = "${gpuiComponent}/skills/gpui-kit-design-guides";
}

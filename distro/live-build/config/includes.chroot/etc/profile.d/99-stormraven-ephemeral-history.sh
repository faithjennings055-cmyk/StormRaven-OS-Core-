# StormRaven OS — Phase 1 Ephemeral Forensic Shell Posture (#89)
# Disable persistent bash history so interactive commands stay in RAM only.
export HISTFILE=/dev/null
export HISTSIZE=500
export HISTFILESIZE=0
export LESSHISTFILE=-

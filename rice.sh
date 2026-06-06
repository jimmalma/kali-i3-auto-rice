#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

echo "🎨 Starting the ultimate Kali-i3 Rice Script..."
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Detect which shell the user is running (Zsh or Bash)
CURRENT_SHELL=$(basename "$SHELL")
SHELL_RC="$HOME/.${CURRENT_SHELL}rc"

# -----------------------------------------------------------------------------
# 1. Update & Install Core Dependencies 
# -----------------------------------------------------------------------------
echo "📦 Updating system and installing core tools..."
sudo apt update && sudo apt install -y \
    cmake \
    pkg-config \
    libx11-dev \
    libxrandr-dev \
    libxtst-dev \
    libgudev-1.0-dev \
    build-essential \
    unzip \
    curl \
    git \
    tmux \
    picom \
    kitty \
    ripgrep \
    fd-find \
    fzf \
    bat \
    wget

# -----------------------------------------------------------------------------
# 2. Install Neovim AppImage (Only if missing)
# -----------------------------------------------------------------------------
if [ ! -f "/usr/local/bin/nvim" ]; then
    echo "📥 Installing latest stable Neovim via AppImage..."
    sudo rm -rf /opt/nvim /tmp/nvim-linux-x86_64.appimage
    sudo mkdir -p /opt/nvim

    sudo wget https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.appimage -O /opt/nvim/nvim
    sudo chmod +x /opt/nvim/nvim
    sudo ln -sf /opt/nvim/nvim /usr/local/bin/nvim
else
    echo "✅ Neovim binary already exists. Skipping download."
fi

# -----------------------------------------------------------------------------
# 3. Install Yazi via GitHub Releases 
# -----------------------------------------------------------------------------
if [ ! -f "/usr/local/bin/yazi" ]; then
    echo "📥 Installing latest stable Yazi from GitHub..."
    sudo rm -rf /tmp/yazi* /opt/yazi
    mkdir -p /tmp/yazi-download

    YAZI_URL=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep "browser_download_url.*x86_64-unknown-linux-gnu.zip" | cut -d '"' -f 4)

    if [ -z "$YAZI_URL" ]; then
        echo "⚠️ Failed to fetch Yazi download URL automatically, falling back to backup mirror..."
        YAZI_URL="https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip"
    fi

    wget "$YAZI_URL" -O /tmp/yazi-download/yazi.zip
    unzip -q /tmp/yazi-download/yazi.zip -d /tmp/yazi-download

    sudo mkdir -p /opt/yazi
    sudo cp /tmp/yazi-download/yazi-*/yazi /usr/local/bin/
    sudo cp /tmp/yazi-download/yazi-*/ya /usr/local/bin/
    rm -rf /tmp/yazi-download
else
    echo "✅ Yazi binary already exists. Skipping download."
fi

# -----------------------------------------------------------------------------
# 4. Install JetBrainsMono Nerd Font 
# -----------------------------------------------------------------------------
if [ ! -f "$HOME/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf" ]; then
    echo "📥 Installing JetBrainsMono Nerd Font..."
    mkdir -p ~/.local/share/fonts
    curl -fLo "$HOME/.local/share/fonts/JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -o ~/.local/share/fonts/JetBrainsMono.zip -d ~/.local/share/fonts/
    fc-cache -fv
    rm -f ~/.local/share/fonts/JetBrainsMono.zip
else
    echo "✅ JetBrainsMono Nerd Font is already present. Skipping download."
fi

# -----------------------------------------------------------------------------
# 5. Shell Integration: Starship, Isolated FZF Layouts, & Yazi Wrapper
# -----------------------------------------------------------------------------
if [ ! -f "/usr/local/bin/starship" ]; then
    echo "🚀 Installing Starship Prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
else
    echo "✅ Starship binary already exists. Skipping installation."
fi

# Overwrite environment variables safely inside Shell RC (.bashrc or .zshrc)
if [ -f "$SHELL_RC" ]; then
    cp "$SHELL_RC" "$BACKUP_DIR/"
    
    # Strip any previous custom rice block to prevent duplicate stacking
    sed -i '/# --- Custom Rice Environment ---/,$d' "$SHELL_RC"

    echo "⚙️ Updating environment configs inside $SHELL_RC..."
    cat << EOF >> "$SHELL_RC"

# --- Custom Rice Environment ---
# Starship initialization
eval "\$(starship init $CURRENT_SHELL)"

# Batcat alias (Kali aliases 'bat' as 'batcat' to avoid package conflict)
alias bat="batcat"

# FZF Global Core Theme Options
export FZF_DEFAULT_OPTS="
  --height 40% 
  --layout=reverse 
  --border 
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc 
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# Isolate file searching previews from Ctrl+R command history lookup windows
export FZF_CTRL_T_OPTS="--preview 'batcat --style=numbers --color=always --line-range :500 {}'"
export FZF_CTRL_R_OPTS="--preview '' --preview-window=hidden"

# Official Yazi terminal tracking file-manager shell wrapper
function y() {
	local tmp="\$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "\$@" --cwd-file="\$tmp"
	if cwd="\$(command cat -- "\$tmp")" && [ -n "\$cwd" ] && [ "\$cwd" != "\$PWD" ]; then
		builtin cd -- "\$cwd"
	fi
	rm -f -- "\$tmp"
}
EOF

    # Dynamically inject the proper fzf key-binding scripts for history Ctrl+R mappings
    if [ "$CURRENT_SHELL" = "zsh" ]; then
        echo -e "\n# Enable FZF Keybindings for Zsh\nsource /usr/share/doc/fzf/examples/key-bindings.zsh" >> "$SHELL_RC"
    elif [ "$CURRENT_SHELL" = "bash" ]; then
        echo -e "\n# Enable FZF Keybindings for Bash\nsource /usr/share/doc/fzf/examples/key-bindings.bash" >> "$SHELL_RC"
    fi
fi

# Write out the dynamic, user-adaptive Catppuccin prompt stylesheet for Starship (Fixed format variables)
mkdir -p "$HOME/.config"
cat << 'EOF' > "$HOME/.config/starship.toml"
format = """
[░▒▓](#89b4fa)\
$username\
[▓▒░](fg:#89b4fa bg:#45475a)\
$directory\
[▓▒░](fg:#45475a bg:#1e1e2e)\
$git_branch\
$git_status\
$character\
"""

[username]
show_always = true
style_user = "bg:#89b4fa fg:#11111b bold"
style_root = "bg:#f38ba8 fg:#11111b bold"
format = "[ 👾 $user ]($style)"

[directory]
style = "bg:#45475a fg:#cdd6f4 bold"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = " "
style = "fg:#f5c2e7 bold"
format = "on [$symbol$branch]($style) "

[git_status]
style = "fg:#f38ba8"
format = "([$all_status$ahead_behind]($style)) "

[character]
success_symbol = "[ ➜](bold #a6e3a1)"
error_symbol = "[ ✗](bold #f38ba8)"
EOF

# -----------------------------------------------------------------------------
# 6. Configure i3 Gaps & Terminal Keybind 
# -----------------------------------------------------------------------------
echo "⚙️ Refreshing i3 config parameters..."
if [ -f "$HOME/.config/i3/config" ]; then
    cp "$HOME/.config/i3/config" "$BACKUP_DIR/"
    sed -i '/# --- Custom Rice Additions ---/,$d' "$HOME/.config/i3/config"
    sed -i '/# --- Custom Rice Automation ---/,$d' "$HOME/.config/i3/config"
fi
mkdir -p "$HOME/.config/i3"

cat << 'EOF' >> "$HOME/.config/i3/config"

# --- Custom Rice Additions ---
# Set Kitty as default terminal matching your layout variable
bindsym $modkey+Return exec kitty

# Gaps configuration
gaps inner 12
gaps outer 4
smart_gaps on
smart_borders on

# Window borders configuration
default_border pixel 2
default_floating_border pixel 2

# --- Custom Rice Automation ---
# Automatically run clipboard fix and picom compositor on startup/reboot
exec_always --no-startup-id ~/.config/i3/autostart.sh
EOF

# -----------------------------------------------------------------------------
# 7. Create Dedicated Persistent Startup Script
# -----------------------------------------------------------------------------
echo "⚙️ Engineering automated persistent boot-script..."
mkdir -p "$HOME/.config/i3"

cat << 'EOF' > "$HOME/.config/i3/autostart.sh"
#!/usr/bin/env bash

# 1. Fix the VMware Clipboard Issue on Boot
killall -q vmtoolsd || true
vmtoolsd -n vmusr >/dev/null 2>&1 &

# Give the virtual machine display server 2 seconds to settle drivers before loading graphics
sleep 2

# 2. Fix the Picom Boot Issue
killall -q picom || true
picom --config ~/.config/picom/picom.conf -b
EOF

chmod +x "$HOME/.config/i3/autostart.sh"

# -----------------------------------------------------------------------------
# 8. Picom Transparency & Blur Setup 
# -----------------------------------------------------------------------------
echo "✨ Updating Picom configuration..."
mkdir -p "$HOME/.config/picom"
cat << 'EOF' > "$HOME/.config/picom/picom.conf"
backend = "glx";
vsync = true;

# Opacity / Transparency settings
active-opacity = 0.93;
inactive-opacity = 0.85;
frame-opacity = 0.90;
inactive-opacity-override = false;

opacity-rule = [
    "100:class_g = 'Firefox'",
    "100:class_g = 'Chromium'",
    "100:class_g = 'Burp Suite'",
    "90:class_g = 'kitty' && focused",
    "80:class_g = 'kitty' && !focused"
];

# Dual Kawase Blur configurations
blur-method = "dual_kawase";
blur-strength = 4;
blur-background = true;
blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "_GTK_FRAME_EXTENTS@"
];

# Window transitions and animations
fading = true;
fade-delta = 4;
fade-in-step = 0.03;
fade-out-step = 0.03;

# Window structural roundings
corner-radius = 10;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];
EOF

# -----------------------------------------------------------------------------
# 9. Kitty Terminal Stylesheet
# -----------------------------------------------------------------------------
echo "🐱 Updating Kitty Terminal styles..."
mkdir -p "$HOME/.config/kitty"
cat << 'EOF' > "$HOME/.config/kitty/kitty.conf"
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size 11.0

# Window Layout & Padding
window_padding_width 15
confirm_os_window_close 0
enable_audio_bell no

# Transparency Configuration
background_opacity 0.85
dynamic_background_opacity yes

# Cyberpunk / Dark Catppuccin color profile
background #1e1e2e
foreground #cdd6f4
selection_background #f5e0dc
selection_foreground #1e1e2e
color0 #45475a
color8 #585b70
color1 #f38ba8
color9 #f38ba8
color2 #a6e3a1
color10 #a6e3a1
color3 #f9e2af
color11 #f9e2af
color4 #89b4fa
color12 #89b4fa
color5 #f5c2e7
color13 #f5c2e7
color6 #94e2d5
color14 #94e2d5
color7 #bac2de
color15 #a6adc8
EOF

# -----------------------------------------------------------------------------
# 10. LazyVim Installation Framework 
# -----------------------------------------------------------------------------
if [ ! -d "$HOME/.config/nvim" ]; then
    echo "⚡ Installing LazyVim ecosystem..."
    rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
else
    echo "✅ LazyVim folder already exists. Skipping repo clone."
fi

# -----------------------------------------------------------------------------
# 11. Tmux Configurations, Base-1 Numbering, Vim Copy & Pane Resizing Bindings
# -----------------------------------------------------------------------------
echo "📟 Updating Tmux profiles..."
cat << 'EOF' > "$HOME/.tmux.conf"
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:Cc=\E]12;%p1%s\007"

# Bind modifier from standard Ctrl+b to comfortable Ctrl+a
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Panel divisions mapping out to pipeline characters
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Vim-centric movement mappings across panes
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Repeatable Vim panel resizing using Shift+H,J,K,L (5-pixel steps)
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

set -g mouse on
set-option -g allow-rename off

# --- Index Customization (Start at 1) ---
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# --- Vim Copy/Paste Mode Configs ---
set-w -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# Dark theme palette footer status layout
set -g status-style bg='#1e1e2e',fg='#cdd6f4'
set -g status-left '#[bg=#89b4fa,fg=#11111b,bold] 👾 #S '
set -g status-right '#[bg=#45475a,fg=#cdd6f4] 🕒 %H:%M │ %Y-%m-%d '
set -g window-status-current-format '#[bg=#f5c2e7,fg=#11111b,bold] #I:#W '
set -g window-status-format '#[fg=#a6adc8] #I:#W '
EOF

# -----------------------------------------------------------------------------
# Compilation Complete Wrap Up
# -----------------------------------------------------------------------------
echo "✨ Complete system optimization finished!"
echo "📂 Backups stored safely in: $BACKUP_DIR"
echo "🔄 Reload your desktop: Press modkey+Shift+r"
echo "📟 Run this to activate your tools live in this panel: source $SHELL_RC"

# Trigger a one-time script execution immediately for this session
~/.config/i3/autostart.sh
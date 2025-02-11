# README

**Usage:** 
Place the ```workspace_manager.sh``` file in your home directory and make it executable:
```bash
chmod +x workspace_manager.sh
```
Add the following line to your ```.bashrc``` or ```.zshrc```:
```bash
# Workspace manager
if [ -f "$HOME/workspace_manager.sh" ]; then
    bash "$HOME/workspace_manager.sh"
fi
```
---
version = 1.0.0
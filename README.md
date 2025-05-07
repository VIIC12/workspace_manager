# README
- Does manage workspaces on HPC Leipzig automatically.
- If remaining days of ws < WARNING_DAYS → extend by EXTENSION_DAYS
- If ws expired, create new ws. Currently we can't automatically restore the old workspace into the new one, but the script print the command to do so manually.
- The script checks for updates and will update itself if a new version is available.

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
version = 1.0.2
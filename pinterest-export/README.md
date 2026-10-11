# Pinterest board export

## Easiest: in your browser
1. Log in to Pinterest and open https://www.pinterest.com/spirit0447/halo-raves/
2. Press **F12** (Mac: **Cmd+Option+J**) and click **Console**. If Chrome warns about pasting, type `allow pasting` and press Enter.
3. Paste everything in [`console-export.js`](console-export.js) and press Enter.
4. Wait for **DONE**. `halo-pins.json` downloads automatically. Send that file to HALO.

## Easiest (Windows): one line, no installs, no git
Open **PowerShell**, paste this, press Enter:
```
irm https://raw.githubusercontent.com/HALORAVES/halo-bot-files/main/pinterest-export/run.ps1 | iex
```
When it finishes it prints **COPY THIS LINK AND PASTE IT TO HALO: ...** (also on your clipboard). Paste that link to HALO.

Saves every pin of https://www.pinterest.com/spirit0447/halo-raves/ (including sections) into `pins/` (images named by pin id) and `pins.json` (id, created_at, title, description, link, image_url, section).

## 1. Install Python (once)
- **Mac:** download from https://www.python.org/downloads/ and install. Open **Terminal**.
- **Windows:** download from https://www.python.org/downloads/, tick **"Add Python to PATH"** while installing. Open **Command Prompt**.

## 2. Run it
```
cd path/to/halo-bot-files/pinterest-export
pip install requests
python export_board.py
```
(On Mac use `pip3` and `python3` if `pip`/`python` aren't found.)

If it reports fewer pins than the board has, export your Pinterest cookies as `cookies.txt` (e.g. the "Get cookies.txt LOCALLY" browser extension while logged in on pinterest.com), put it in this folder, and run:
```
python export_board.py --cookies cookies.txt
```
**Never commit cookies.txt** (it's in .gitignore).

## Windows alternative: PowerShell (no Python needed)
Open **PowerShell**, then:
```
cd path\to\halo-bot-files\pinterest-export
Set-ExecutionPolicy -Scope Process Bypass
.\export_board.ps1
```
Options: `.\export_board.ps1 -Cookies cookies.txt` (if it finds fewer pins than the board has) and `-NoImages` (only write pins.json).

## 3. Send it back to GitHub
```
cd ..
git add pinterest-export
git commit -m "Pinterest board export"
git push
```
No git? On github.com open the `pinterest-export` folder → **Add file → Upload files**, drag in `pins.json` and the `pins` folder, then **Commit changes**.

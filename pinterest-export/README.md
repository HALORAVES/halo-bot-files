# Pinterest board export

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

## 3. Send it back to GitHub
```
cd ..
git add pinterest-export
git commit -m "Pinterest board export"
git push
```
No git? On github.com open the `pinterest-export` folder → **Add file → Upload files**, drag in `pins.json` and the `pins` folder, then **Commit changes**.

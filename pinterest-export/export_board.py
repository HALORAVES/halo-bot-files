#!/usr/bin/env python3
"""Export every pin of a public Pinterest board (incl. sections).

Usage:
    python export_board.py                       # default HALO board
    python export_board.py --board spirit0447/halo-raves
    python export_board.py --cookies cookies.txt # optional, Netscape cookies.txt
Output (next to this script):
    pins/<pin_id>.<ext>
    pins.json
"""
import argparse, http.cookiejar, json, os, sys, time
from urllib.parse import urlencode
try:
    import requests
except ImportError:
    sys.exit("Please run:  pip install requests")

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://www.pinterest.com"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")


def make_session(cookies_path):
    s = requests.Session()
    s.headers.update({"User-Agent": UA, "Accept": "application/json, text/javascript, */*; q=0.01",
                      "X-Requested-With": "XMLHttpRequest", "X-Pinterest-AppState": "active",
                      "Accept-Language": "en-US,en;q=0.9"})
    if cookies_path:
        cj = http.cookiejar.MozillaCookieJar(cookies_path)
        cj.load(ignore_discard=True, ignore_expires=True)
        s.cookies.update(cj)
    s.get(BASE + "/", timeout=30)  # picks up csrftoken
    tok = s.cookies.get("csrftoken")
    if tok:
        s.headers["X-CSRFToken"] = tok
    return s


def resource(s, name, options, source_url):
    r = s.get(f"{BASE}/resource/{name}/get/",
              params={"source_url": source_url,
                      "data": json.dumps({"options": options, "context": {}}),
                      "_": int(time.time() * 1000)},
              headers={"Referer": BASE + source_url}, timeout=30)
    r.raise_for_status()
    rr = r.json().get("resource_response", {})
    return rr.get("data"), rr.get("bookmark")


def paginate(s, name, options, source_url):
    bookmark = None
    while True:
        opts = dict(options)
        if bookmark:
            opts["bookmarks"] = [bookmark]
        data, bookmark = resource(s, name, opts, source_url)
        for item in data or []:
            yield item
        if not data or not bookmark or bookmark == "-end-":
            return
        time.sleep(0.6)


def best_image(pin):
    imgs = pin.get("images") or {}
    for k in ("orig", "originals", "1200x", "736x", "474x", "236x"):
        if k in imgs and imgs[k].get("url"):
            return imgs[k]["url"]
    return None


def row(pin, section):
    return {"id": str(pin.get("id")), "created_at": pin.get("created_at"),
            "title": pin.get("title") or pin.get("grid_title"),
            "description": pin.get("description"), "link": pin.get("link"),
            "image_url": best_image(pin), "section": section}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--board", default="spirit0447/halo-raves")
    ap.add_argument("--cookies", help="optional Netscape cookies.txt exported from your browser")
    ap.add_argument("--no-images", action="store_true")
    a = ap.parse_args()
    user, slug = a.board.strip("/").split("/")[:2]
    src = f"/{user}/{slug}/"
    s = make_session(a.cookies)

    board, _ = resource(s, "BoardResource", {"username": user, "slug": slug, "field_set_key": "detailed"}, src)
    if not board or not board.get("id"):
        sys.exit("Could not load board. Check the name, or try --cookies cookies.txt")
    bid = board["id"]
    print(f"Board: {board.get('name')}  id={bid}  pins~{board.get('pin_count')}")

    pins = {}
    def add(p, section):
        if p.get("type", "pin") != "pin" or not p.get("id"):
            return
        pid = str(p["id"])
        if pid not in pins or (section and not pins[pid]["section"]):
            pins[pid] = row(p, section)

    for p in paginate(s, "BoardFeedResource", {"board_id": bid, "board_url": src, "page_size": 25,
                                              "field_set_key": "react_grid_pin", "layout": "default"}, src):
        add(p, None)
    print(f"Main feed: {len(pins)} pins")

    for sec in paginate(s, "BoardSectionsResource", {"board_id": bid, "page_size": 25}, src):
        sid, title = sec.get("id"), sec.get("title")
        if not sid:
            continue
        before = len(pins)
        for p in paginate(s, "BoardSectionPinsResource", {"section_id": sid, "page_size": 25}, src):
            add(p, title)
        print(f"Section '{title}': +{len(pins) - before} new")

    print(f"Total unique pins: {len(pins)}")
    if board.get("pin_count") and len(pins) < board["pin_count"]:
        print("NOTE: fewer than the board count. Try again with --cookies cookies.txt")

    out_dir = os.path.join(HERE, "pins"); os.makedirs(out_dir, exist_ok=True)
    if not a.no_images:
        for i, p in enumerate(pins.values(), 1):
            url = p["image_url"]
            if not url:
                continue
            ext = os.path.splitext(url.split("?")[0])[1] or ".jpg"
            path = os.path.join(out_dir, p["id"] + ext)
            p["file"] = "pins/" + p["id"] + ext
            if os.path.exists(path):
                continue
            try:
                r = s.get(url, timeout=60); r.raise_for_status()
                with open(path, "wb") as f:
                    f.write(r.content)
            except Exception as e:
                print(f"  image failed {p['id']}: {e}")
            if i % 25 == 0:
                print(f"  {i}/{len(pins)} images")
    with open(os.path.join(HERE, "pins.json"), "w", encoding="utf-8") as f:
        json.dump(sorted(pins.values(), key=lambda x: x["id"]), f, indent=2, ensure_ascii=False)
    print("Done. Wrote pins.json and pins/ folder.")


if __name__ == "__main__":
    main()

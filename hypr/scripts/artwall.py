#!/usr/bin/python3
"""artwall - rotate public-domain museum paintings as desktop and hyprlock wallpaper.

Subcommands:
  next      pick an unseen painting, render per-monitor images, set them with awww
            (no-op if the current one is under 55 minutes old; add --force to skip anyway)
  render    re-render the current painting (e.g. after a monitor change)
  refill    download paintings until the library holds TARGET_UNSEEN unseen pieces
  info      print the current painting
  block     blocklist the current painting and advance to the next one
  prune     remove downloaded museum pieces that fail the current curation rules

Sources (no API key needed, all public domain / CC0):
  - The Metropolitan Museum of Art Open Access API
  - Cleveland Museum of Art Open Access API
"""

from __future__ import annotations

import json
import os
import random
import re
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import requests
from PIL import Image, ImageDraw, ImageFilter, ImageFont

Image.MAX_IMAGE_PIXELS = None  # museum scans are large; we downscale ourselves

# ---------------------------------------------------------------- configuration

HOME = Path.home()
DATA_DIR = HOME / ".local/share/artwall"
LIBRARY_DIR = DATA_DIR / "library"
STATE_FILE = DATA_DIR / "state.json"
BLOCKLIST_FILE = DATA_DIR / "blocklist.txt"
CACHE_DIR = HOME / ".cache/artwall"
FONT_DIR = HOME / ".local/share/fonts/artwall"
FONT_REGULAR = FONT_DIR / "CormorantGaramond[wght].ttf"
FONT_ITALIC = FONT_DIR / "CormorantGaramond-Italic[wght].ttf"
FONT_URLS = {
    FONT_REGULAR: "https://raw.githubusercontent.com/google/fonts/main/ofl/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf",
    FONT_ITALIC: "https://raw.githubusercontent.com/google/fonts/main/ofl/cormorantgaramond/CormorantGaramond-Italic%5Bwght%5D.ttf",
}

TARGET_UNSEEN = 30        # keep this many not-yet-shown paintings downloaded
MIN_LONG_SIDE = 2400      # reject source images smaller than this on their long side
ASPECT_RANGE = (0.45, 2.4)  # reject scroll strips and other extreme shapes
# titles that mark catalogue material rather than pictures
EXCLUDE_TITLE = re.compile(r"\b(folio|text page|manuscript|fragment|page from|leaf from|study|studies|sketch|copy after|portrait|self-portrait|head of|bust of|madame|monsieur|mrs\.|mr\.|miss)\b", re.I)
HISTORY_LEN = 200         # remember this many shown pieces to avoid repeats
MIN_INTERVAL = 55 * 60    # never change the painting more often than this unless forced
USER_AGENT = "artwall/0.1 (personal wallpaper rotator; contact via github.com/tyler-marques)"
# Quality gate for pieces found by browsing museum collections (curated works skip it).
# Colourfulness is Hasler & Süsstrunk's metric on a 256px thumbnail; vivid paintings score 35+.
MIN_COLOURFULNESS = 34
MIN_BRIGHTNESS = 55
COMMONS_WIDTH = 6000      # request Commons files scaled to this width (originals can be 40k px)
TRANSITION = ["--transition-type", "fade", "--transition-duration", "3", "--transition-fps", "60"]
SYNC_COLORS = False  # regenerate the shell's Material colours from the painting (Quickshell, kitty, Hyprland border)

# Look of the rendered wall
MARGIN_FRAC = 0.05        # margin around the painting, fraction of the short canvas side
WALL_BLUR = 14            # blur radius applied to the 1/8-scale backdrop
WALL_DARKEN = 0.32        # backdrop brightness multiplier
SHADOW_ALPHA = 150
TEXT_COLOR = (236, 229, 216)
TEXT_DIM = (196, 188, 172)

# ------------------------------------------------------------------- utilities


def log(msg: str) -> None:
    print(f"[artwall] {msg}", file=sys.stderr, flush=True)


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    tmp.replace(path)


def atomic_save_image(img: Image.Image, path: Path) -> None:
    """Write via a temp file so hyprlock/awww never read a half-written image."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp.png")
    img.save(tmp, format="PNG", compress_level=1)
    tmp.replace(path)


def http() -> requests.Session:
    s = requests.Session()
    s.headers["User-Agent"] = USER_AGENT
    return s


def blocklist() -> set[str]:
    try:
        return {l.strip() for l in BLOCKLIST_FILE.read_text().splitlines() if l.strip()}
    except FileNotFoundError:
        return set()


def ensure_fonts() -> None:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    missing = [p for p in FONT_URLS if not p.exists()]
    if not missing:
        return
    s = http()
    for p in missing:
        log(f"downloading font {p.name}")
        r = s.get(FONT_URLS[p], timeout=60)
        r.raise_for_status()
        p.write_bytes(r.content)
    subprocess.run(["fc-cache", "-f"], check=False)


# --------------------------------------------------------------------- library


@dataclass
class Artwork:
    id: str          # "<source>-<object id>"
    source: str
    title: str
    artist: str
    date: str
    url: str         # museum page for attribution
    file: str        # filename inside LIBRARY_DIR
    width: int = 0
    height: int = 0

    @property
    def path(self) -> Path:
        return LIBRARY_DIR / self.file

    @property
    def credit(self) -> str:
        parts = [p for p in (self.artist, self.date) if p]
        return ", ".join(parts)


def library() -> dict[str, Artwork]:
    works = {}
    for meta in LIBRARY_DIR.glob("*.json"):
        d = load_json(meta, None)
        if d and (LIBRARY_DIR / d["file"]).exists():
            works[d["id"]] = Artwork(**d)
    return works


def download_image(s: requests.Session, url: str, dest: Path) -> tuple[int, int] | None:
    tmp = dest.with_suffix(dest.suffix + ".part")
    with s.get(url, stream=True, timeout=120) as r:
        r.raise_for_status()
        with open(tmp, "wb") as f:
            shutil.copyfileobj(r.raw, f)
    try:
        with Image.open(tmp) as im:
            w, h = im.size
        if max(w, h) < MIN_LONG_SIDE or not (ASPECT_RANGE[0] <= w / h <= ASPECT_RANGE[1]):
            tmp.unlink()
            return None
    except Exception:
        tmp.unlink(missing_ok=True)
        return None
    tmp.replace(dest)
    return w, h


def vividness(path: Path) -> tuple[float, float]:
    """(colourfulness, mean brightness) of an image, measured on a small thumbnail."""
    import math
    with Image.open(path) as im:
        im = im.convert("RGB")
        im.thumbnail((256, 256))
        px = list(im.get_flattened_data()) if hasattr(im, "get_flattened_data") else list(im.getdata())
        lum = sum(0.299 * r + 0.587 * g + 0.114 * b for r, g, b in px) / len(px)
    n = len(px)
    rg = [r - g for r, g, b in px]
    yb = [0.5 * (r + g) - b for r, g, b in px]

    def stats(v):
        m = sum(v) / n
        return m, math.sqrt(sum((x - m) ** 2 for x in v) / n)

    mrg, srg = stats(rg)
    myb, syb = stats(yb)
    return math.sqrt(srg**2 + syb**2) + 0.3 * math.sqrt(mrg**2 + myb**2), lum


def vivid_enough(path: Path) -> bool:
    col, lum = vividness(path)
    ok = col >= MIN_COLOURFULNESS and lum >= MIN_BRIGHTNESS
    if not ok:
        log(f"rejected (colourfulness {col:.0f}, brightness {lum:.0f}): {path.name}")
    return ok


def art_key(art: Artwork) -> tuple[str, str]:
    """Same painting from two museums: compare a normalised title and the artist's surname."""
    title = re.sub(r"[^a-z0-9 ]", "", art.title.lower().split("(")[0]).strip()
    return title, art.artist.lower().split()[-1] if art.artist else ""


def _save_artwork(art: Artwork) -> None:
    save_json(LIBRARY_DIR / f"{art.id}.json", asdict(art))


# --- curation --------------------------------------------------------------

# Artists whose collection works are browsed at the museums (then gated by vividness).
ARTISTS = [
    "Vincent van Gogh", "Claude Monet", "Paul Gauguin", "Paul Cézanne", "Pierre-Auguste Renoir",
    "Georges Seurat", "Paul Signac", "Gustav Klimt", "Joseph Mallord William Turner",
    "Albert Bierstadt", "Frederic Edwin Church", "Thomas Cole", "Thomas Moran", "Sanford Robinson Gifford",
    "Martin Johnson Heade", "Jasper Francis Cropsey", "John Frederick Kensett",
    "Katsushika Hokusai", "Utagawa Hiroshige", "Vasily Kandinsky", "Franz Marc", "Pierre Bonnard",
    "Odilon Redon", "Childe Hassam", "Maurice Prendergast", "John Singer Sargent", "Winslow Homer",
    "Henri Rousseau", "Camille Pissarro", "Alfred Sisley", "Berthe Morisot", "Louis Comfort Tiffany",
    "Hilma af Klint", "Edvard Munch", "Egon Schiele", "Emil Nolde", "August Macke",
]
ARTISTS_PER_REFILL = 6
PRINTMAKERS = {"Katsushika Hokusai", "Utagawa Hiroshige"}

# Hand-picked iconic works fetched from Wikimedia Commons: (title, artist, date, search, must-match regex)
ICONIC = [
    ("The Starry Night", "Vincent van Gogh", "1889", "Van Gogh Starry Night Google Art Project", r"Starry Night - Google Art Project"),
    ("Starry Night Over the Rhône", "Vincent van Gogh", "1888", "Van Gogh Starry Night Over the Rhone", r"Rh[oô]ne"),
    ("Café Terrace at Night", "Vincent van Gogh", "1888", "Van Gogh Cafe Terrace at Night", r"Caf[eé] Terrace|Terrasse"),
    ("Irises", "Vincent van Gogh", "1889", "Van Gogh Irises Getty Google Art Project", r"Irises"),
    ("Wheat Field with Cypresses", "Vincent van Gogh", "1889", "Van Gogh Wheat Field with Cypresses Metropolitan", r"Cypress"),
    ("Almond Blossom", "Vincent van Gogh", "1890", "Van Gogh Almond Blossom Google Art Project", r"Almond"),
    ("Sunflowers", "Vincent van Gogh", "1888", "Vincent Willem van Gogh 127 Sunflowers National Gallery London", r"Sunflowers|Zonnebloemen|van Gogh 127"),
    ("The Bedroom", "Vincent van Gogh", "1889", "Van Gogh The Bedroom Art Institute of Chicago Google Art Project", r"Bedroom"),
    ("Under the Wave off Kanagawa (The Great Wave)", "Katsushika Hokusai", "c. 1830–32", "Great Wave off Kanagawa MET DP141042", r"Kanagawa"),
    ("Fine Wind, Clear Morning (Red Fuji)", "Katsushika Hokusai", "c. 1830–32", "Hokusai Red Fuji South Wind Clear Morning", r"Fuji|Fine Wind|South Wind|Red"),
    ("Kirifuri Waterfall at Kurokami Mountain", "Katsushika Hokusai", "c. 1832", "Hokusai Kirifuri Waterfall", r"Kirifuri"),
    ("Sudden Shower over Shin-Ōhashi Bridge and Atake", "Utagawa Hiroshige", "1857", "Hiroshige Sudden Shower over Shin-Ohashi bridge and Atake", r"Shin-?[OŌ]hashi|Sudden Shower|Atake"),
    ("Plum Park in Kameido", "Utagawa Hiroshige", "1857", "Hiroshige Plum Park in Kameido", r"Kameido|Plum"),
    ("Impression, Sunrise", "Claude Monet", "1872", "Monet Impression Sunrise", r"Impression"),
    ("Woman with a Parasol", "Claude Monet", "1875", "Monet Woman with a Parasol Madame Monet and Her Son", r"Parasol"),
    ("Bridge over a Pond of Water Lilies", "Claude Monet", "1899", "Claude Monet Bridge over a Pond of Water Lilies Metropolitan Museum", r"Water.?Lil|Nymph[eé]as|Bridge"),
    ("Poppy Field", "Claude Monet", "1873", "Monet Poppies Coquelicots Orsay", r"Poppies|Coquelicots|Poppy"),
    ("The Kiss", "Gustav Klimt", "1907–08", "Klimt The Kiss Google Art Project", r"Kiss"),
    ("Portrait of Adele Bloch-Bauer I", "Gustav Klimt", "1907", "Klimt Adele Bloch-Bauer I", r"Bloch-Bauer"),
    ("The Fighting Temeraire", "J. M. W. Turner", "1839", "Turner The Fighting Temeraire", r"Temeraire"),
    ("Rain, Steam and Speed", "J. M. W. Turner", "1844", "Turner Rain Steam and Speed Great Western Railway", r"Rain,? Steam"),
    ("Among the Sierra Nevada, California", "Albert Bierstadt", "1868", "Bierstadt Among the Sierra Nevada California", r"Sierra Nevada"),
    ("A Storm in the Rocky Mountains, Mt. Rosalie", "Albert Bierstadt", "1866", "Bierstadt Storm in the Rocky Mountains Mt Rosalie", r"Rosalie|Rocky Mountains"),
    ("Heart of the Andes", "Frederic Edwin Church", "1859", "Church Heart of the Andes", r"Heart of the Andes"),
    ("Niagara", "Frederic Edwin Church", "1857", "Frederic Edwin Church Niagara 1857", r"Niagara"),
    ("Cotopaxi", "Frederic Edwin Church", "1862", "Frederic Edwin Church Cotopaxi 1862", r"Cotopaxi"),
    ("Twilight in the Wilderness", "Frederic Edwin Church", "1860", "Church Twilight in the Wilderness", r"Twilight in the Wilderness"),
    ("The Oxbow", "Thomas Cole", "1836", "Thomas Cole The Oxbow View from Mount Holyoke", r"Oxbow"),
    ("The Grand Canyon of the Yellowstone", "Thomas Moran", "1872", "Thomas Moran Grand Canyon of the Yellowstone 1872", r"Yellowstone"),
    ("Composition VII", "Wassily Kandinsky", "1913", "Kandinsky Composition VII", r"Composition VII\b"),
    ("Composition VIII", "Wassily Kandinsky", "1923", "Kandinsky Composition VIII", r"Composition VIII"),
    ("A Sunday on La Grande Jatte", "Georges Seurat", "1884–86", "Seurat A Sunday on La Grande Jatte Google Art Project", r"Grande Jatte"),
    ("The Garden of Earthly Delights", "Hieronymus Bosch", "c. 1490–1510", "Bosch The Garden of Earthly Delights Prado", r"Garden of Earthly Delights"),
    ("The Birth of Venus", "Sandro Botticelli", "c. 1484–86", "Botticelli Birth of Venus Google Art Project", r"Birth of Venus|Nascita di Venere"),
    ("Primavera", "Sandro Botticelli", "c. 1480", "Botticelli Primavera Google Art Project", r"Primavera"),
    ("The Tower of Babel", "Pieter Bruegel the Elder", "1563", "Bruegel Tower of Babel Vienna Google Art Project", r"Babel"),
    ("The Hunters in the Snow", "Pieter Bruegel the Elder", "1565", "Bruegel Hunters in the Snow", r"Hunters in the Snow|Jäger"),
    ("Wanderer above the Sea of Fog", "Caspar David Friedrich", "1818", "Caspar David Friedrich Wanderer above the Sea of Fog", r"Wanderer"),
    ("The Ninth Wave", "Ivan Aivazovsky", "1850", "Aivazovsky The Ninth Wave", r"Ninth Wave"),
    ("Liberty Leading the People", "Eugène Delacroix", "1830", "Delacroix Liberty Leading the People", r"Liberty|Libert[eé]"),
    ("Bal du moulin de la Galette", "Pierre-Auguste Renoir", "1876", "Renoir Bal du moulin de la Galette Orsay", r"Galette"),
    ("Luncheon of the Boating Party", "Pierre-Auguste Renoir", "1880–81", "Renoir Luncheon of the Boating Party", r"Boating Party"),
    ("The Dream", "Henri Rousseau", "1910", "Henri Rousseau The Dream 1910", r"Dream|Rêve"),
    ("The Sleeping Gypsy", "Henri Rousseau", "1897", "Henri Rousseau The Sleeping Gypsy", r"Gypsy|Bohémienne"),
    ("The Scream", "Edvard Munch", "1893", "Edvard Munch The Scream National Gallery Norway", r"Scream|Skrik"),
    ("The Large Blue Horses", "Franz Marc", "1911", "Franz Marc The Large Blue Horses", r"Blue Horses|Blaue Pferde"),
    ("Flaming June", "Frederic Leighton", "1895", "Leighton Flaming June", r"Flaming June"),
    ("The Lady of Shalott", "John William Waterhouse", "1888", "Waterhouse The Lady of Shalott 1888", r"Lady of Shalott"),
    ("The Roses of Heliogabalus", "Lawrence Alma-Tadema", "1888", "Alma-Tadema The Roses of Heliogabalus", r"Heliogabalus"),
    ("Ophelia", "John Everett Millais", "1851–52", "Millais Ophelia Tate", r"Ophelia"),
    ("Where Do We Come From? What Are We? Where Are We Going?", "Paul Gauguin", "1897–98", "Gauguin Where Do We Come From What Are We Where Are We Going", r"Where Do We Come From|D'où venons"),
    ("The Ten Largest, No. 7, Adulthood", "Hilma af Klint", "1907", "Hilma af Klint The Ten Largest No 7 Adulthood", r"Ten Largest|De tio största"),
    ("The Creation of Adam", "Michelangelo", "c. 1512", "Michelangelo Creation of Adam Sistine Chapel", r"Creation of Adam|Creazione di Adamo"),
    ("The School of Athens", "Raphael", "1509–11", "Raphael School of Athens", r"School of Athens|Scuola di Atene"),
]


# --- Wikimedia Commons -------------------------------------------------------

COMMONS_API = "https://commons.wikimedia.org/w/api.php"


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:60]


ICONIC_BY_ID = {f"commons-{slug(t)}": (t, a, d, q, m) for t, a, d, q, m in ICONIC}


def commons_candidates(s: requests.Session, known: set[str]) -> list[str]:
    ids = [i for i in ICONIC_BY_ID if i not in known]
    random.shuffle(ids)
    return ids


def commons_fetch(s: requests.Session, art_id: str) -> Artwork | None:
    title, artist, date, query, must = ICONIC_BY_ID[art_id]
    r = s.get(COMMONS_API, params={
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": 6, "gsrlimit": 10,
        "gsrsearch": f"{query} filetype:bitmap", "prop": "imageinfo",
        "iiprop": "url|size|mime", "iiurlwidth": COMMONS_WIDTH,
    }, timeout=60)
    r.raise_for_status()
    pages = (r.json().get("query") or {}).get("pages") or {}
    best = None
    for pg in pages.values():
        if not re.search(must, pg["title"], re.I):
            continue
        info = (pg.get("imageinfo") or [{}])[0]
        if not info.get("width") or "svg" in info.get("mime", ""):
            continue
        if best is None or info["width"] * info["height"] > best[1]["width"] * best[1]["height"]:
            best = (pg["title"], info)
    if not best:
        log(f"{title}: no Commons match")
        return None
    name, info = best
    url = info.get("thumburl") if info["width"] > COMMONS_WIDTH else info["url"]
    dest = LIBRARY_DIR / f"{art_id}.jpg"
    size = download_image(s, url or info["url"], dest)
    if not size:
        return None
    return Artwork(
        id=art_id, source="Wikimedia Commons", title=title, artist=artist, date=date,
        url=info.get("descriptionurl") or f"https://commons.wikimedia.org/wiki/{name}",
        file=dest.name, width=size[0], height=size[1],
    )


# --- Met ---------------------------------------------------------------------

MET_API = "https://collectionapi.metmuseum.org/public/collection/v1"


def met_candidates(s: requests.Session, known: set[str]) -> list[str]:
    ids: list[str] = []
    for artist in random.sample(ARTISTS, ARTISTS_PER_REFILL):
        r = s.get(f"{MET_API}/search", params={"artistOrCulture": "true", "hasImages": "true", "q": artist}, timeout=60)
        if r.status_code != 200:
            continue
        ids += [f"met-{i}" for i in (r.json().get("objectIDs") or [])[:200]]
    ids = [i for i in dict.fromkeys(ids) if i not in known]
    random.shuffle(ids)
    return ids


def met_fetch(s: requests.Session, art_id: str) -> Artwork | None:
    obj_id = art_id.split("-", 1)[1]
    r = s.get(f"{MET_API}/objects/{obj_id}", timeout=60)
    if r.status_code != 200:
        return None
    o = r.json()
    if not o.get("isPublicDomain") or not o.get("primaryImage"):
        return None
    if o.get("artistDisplayName") not in ARTISTS:  # the search also matches students, copies, "after ..."
        return None
    cls = str(o.get("classification", ""))
    if not (cls.startswith("Paintings") or (cls == "Prints" and o.get("artistDisplayName") in PRINTMAKERS)):
        return None
    if EXCLUDE_TITLE.search(o.get("title") or ""):
        return None
    dest = LIBRARY_DIR / f"{art_id}.jpg"
    size = download_image(s, o["primaryImage"], dest)
    if not size:
        return None
    if not vivid_enough(dest):
        dest.unlink()
        return None
    return Artwork(
        id=art_id, source="The Met",
        title=o.get("title") or "Untitled",
        artist=o.get("artistDisplayName") or "Unknown artist",
        date=o.get("objectDate") or "",
        url=o.get("objectURL") or "",
        file=dest.name, width=size[0], height=size[1],
    )


# --- Cleveland ---------------------------------------------------------------

CMA_API = "https://openaccess-api.clevelandart.org/api/artworks/"


def cma_candidates(s: requests.Session, known: set[str]) -> list[str]:
    ids: list[str] = []
    for artist in random.sample(ARTISTS, ARTISTS_PER_REFILL):
        r = s.get(CMA_API, params={"artists": artist, "cc0": 1, "has_image": 1, "limit": 100, "fields": "id"}, timeout=60)
        if r.status_code != 200:
            continue
        ids += [f"cma-{d['id']}" for d in r.json().get("data", [])]
    ids = [i for i in dict.fromkeys(ids) if i not in known]
    random.shuffle(ids)
    return ids


def cma_fetch(s: requests.Session, art_id: str) -> Artwork | None:
    obj_id = art_id.split("-", 1)[1]
    r = s.get(f"{CMA_API}{obj_id}", timeout=60)
    if r.status_code != 200:
        return None
    o = r.json()["data"]
    img = (o.get("images") or {}).get("print") or {}
    if not img.get("url") or EXCLUDE_TITLE.search(o.get("title") or ""):
        return None
    creator = (o.get("creators") or [{}])[0].get("description") or "Unknown artist"
    artist = creator.split(" (")[0].strip()
    if artist not in ARTISTS:
        return None
    if o.get("type") != "Painting" and not (o.get("type") == "Print" and artist in PRINTMAKERS):
        return None
    dest = LIBRARY_DIR / f"{art_id}.jpg"
    size = download_image(s, img["url"], dest)
    if not size:
        return None
    if not vivid_enough(dest):
        dest.unlink()
        return None
    return Artwork(
        id=art_id, source="Cleveland Museum of Art",
        title=o.get("title") or "Untitled",
        artist=artist,
        date=o.get("creation_date") or "",
        url=o.get("url") or "",
        file=dest.name, width=size[0], height=size[1],
    )


SOURCES = {"commons": (commons_candidates, commons_fetch), "met": (met_candidates, met_fetch), "cma": (cma_candidates, cma_fetch)}


def cmd_refill(target: int = TARGET_UNSEEN) -> None:
    LIBRARY_DIR.mkdir(parents=True, exist_ok=True)
    state = load_json(STATE_FILE, {})
    seen = set(state.get("history", []))
    blocked = blocklist()
    works = library()
    unseen = [w for w in works if w not in seen and w not in blocked]
    need = target - len(unseen)
    if need <= 0:
        log(f"library has {len(unseen)} unseen paintings, nothing to do")
        return
    log(f"need {need} more paintings")
    s = http()
    known = set(works) | blocked
    have = {art_key(w) for w in works.values()}
    candidates: dict[str, list[str]] = {}
    for name, (cands, _) in SOURCES.items():
        try:
            candidates[name] = cands(s, known)
        except Exception as e:  # one source being down should not stop the other
            log(f"{name}: candidate listing failed: {e}")
    added = 0
    while need > 0 and any(candidates.values()):
        avail = [n for n, c in candidates.items() if c]
        name = "commons" if "commons" in avail and random.random() < 0.5 else random.choice(avail)
        art_id = candidates[name].pop()
        try:
            art = SOURCES[name][1](s, art_id)
        except Exception as e:
            log(f"{art_id}: {e}")
            art = None
        if art and art_key(art) in have:
            log(f"duplicate of an existing piece, skipped: {art.title}")
            art.path.unlink(missing_ok=True)
            art = None
        if art:
            _save_artwork(art)
            have.add(art_key(art))
            added += 1
            need -= 1
            log(f"added {art.title} — {art.artist} ({art.width}x{art.height})")
        time.sleep(0.3)
    log(f"refill complete, added {added}")


# -------------------------------------------------------------------- rendering


@dataclass
class Monitor:
    name: str
    width: int   # physical pixels after transform
    height: int


def monitors() -> list[Monitor]:
    out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True).stdout
    mons = []
    for m in json.loads(out):
        w, h = m["width"], m["height"]
        if m.get("transform", 0) % 2 == 1:  # 90/270 degree rotations swap the axes
            w, h = h, w
        mons.append(Monitor(m["name"], w, h))
    return mons


def font(path: Path, size: int, weight: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), size)
    try:
        f.set_variation_by_axes([weight])
    except OSError:
        pass
    return f


def cover(img: Image.Image, w: int, h: int) -> Image.Image:
    scale = max(w / img.width, h / img.height)
    resized = img.resize((round(img.width * scale) or 1, round(img.height * scale) or 1), Image.Resampling.BILINEAR)
    x = (resized.width - w) // 2
    y = (resized.height - h) // 2
    return resized.crop((x, y, x + w, y + h))


def fit(size: tuple[int, int], box: tuple[int, int]) -> tuple[int, int]:
    scale = min(box[0] / size[0], box[1] / size[1])
    return max(1, round(size[0] * scale)), max(1, round(size[1] * scale))


def caption_layout(mon: Monitor, art: Artwork):
    """Return (title_font, credit_font, title, credit, block_w, block_h, gap)."""
    base = round(min(mon.width, mon.height) * 0.030)
    title_f = font(FONT_ITALIC, base, 500)
    credit_f = font(FONT_REGULAR, round(base * 0.62), 500)
    title = art.title
    max_w = round(mon.width * (0.42 if mon.width > mon.height else 0.82))  # portrait screens get most of the width
    # trim over-long titles rather than wrapping; captions should read like a gallery label
    while title_f.getlength(title) > max_w and len(title) > 8:
        title = title[:-2].rstrip(" ,;:-") + "…"
    credit = art.credit
    while credit_f.getlength(credit) > max_w and len(credit) > 8:
        credit = credit[:-2].rstrip(" ,;:-") + "…"
    gap = round(base * 0.35)
    t_box = title_f.getbbox(title)
    c_box = credit_f.getbbox(credit)
    block_w = max(t_box[2] - t_box[0], c_box[2] - c_box[0])
    block_h = (t_box[3] - t_box[1]) + gap + (c_box[3] - c_box[1])
    return title_f, credit_f, title, credit, block_w, block_h, gap


def render_monitor(mon: Monitor, art: Artwork, painting: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Return (captioned, uncaptioned) canvases for one monitor."""
    W, H = mon.width, mon.height
    margin = round(min(W, H) * MARGIN_FRAC)

    # gallery wall: the painting itself, blurred and darkened
    small = cover(painting, max(1, W // 8), max(1, H // 8)).filter(ImageFilter.GaussianBlur(WALL_BLUR))
    wall = small.resize((W, H), Image.Resampling.BICUBIC)
    wall = Image.eval(wall, lambda v: int(v * WALL_DARKEN)).convert("RGBA")

    title_f, credit_f, title, credit, cap_w, cap_h, gap = caption_layout(mon, art)

    # fit the painting; reserve a caption band only when the two would collide
    pw, ph = fit(painting.size, (W - 2 * margin, H - 2 * margin))
    px, py = (W - pw) // 2, (H - ph) // 2
    cap_top = H - margin - cap_h
    cap_left = W - margin - cap_w
    if py + ph > cap_top - gap and px + pw > cap_left - margin:
        band = cap_h + gap
        pw, ph = fit(painting.size, (W - 2 * margin, H - 2 * margin - band))
        px, py = (W - pw) // 2, (H - band - ph) // 2

    # soft drop shadow
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    off = round(margin * 0.18)
    sd.rectangle((px, py + off, px + pw, py + ph + off), fill=(0, 0, 0, SHADOW_ALPHA))
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(margin * 0.4)))
    canvas = Image.alpha_composite(wall, shadow)

    resample = Image.Resampling.LANCZOS
    canvas.paste(painting.resize((pw, ph), resample).convert("RGBA"), (px, py))
    plain = canvas.copy()

    # caption, bottom-right, with a faint shadow for legibility over anything
    text_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    td = ImageDraw.Draw(text_layer)
    right, bottom = W - margin, H - margin
    td.text((right, bottom), credit, font=credit_f, fill=TEXT_DIM, anchor="rd")
    c_h = credit_f.getbbox(credit)[3] - credit_f.getbbox(credit)[1]
    td.text((right, bottom - c_h - gap), title, font=title_f, fill=TEXT_COLOR, anchor="rd")
    shadow_txt = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow_txt.paste((0, 0, 0, 200), mask=text_layer.getchannel("A"))
    shadow_txt = shadow_txt.filter(ImageFilter.GaussianBlur(max(2, title_f.size // 10)))
    canvas = Image.alpha_composite(canvas, shadow_txt)
    canvas = Image.alpha_composite(canvas, text_layer)
    return canvas.convert("RGB"), plain.convert("RGB")


def hyprlock_fragment(mons: list[Monitor]) -> str:
    blocks = []
    for m in mons:
        blocks.append(
            "background {\n"
            f"    monitor = {m.name}\n"
            f"    path = {CACHE_DIR / (m.name + '-lock.png')}\n"
            # hyprlock (<= 0.9.6) only plants its reload timer when reload_cmd is set; the command's
            # output is the path to (re)load, and the image is re-read whenever its mtime changes.
            f"    reload_cmd = echo {CACHE_DIR / (m.name + '-lock.png')}\n"
            "    reload_time = 30\n"
            "    blur_passes = 1\n"
            "    blur_size = 3\n"
            "    brightness = 0.65\n"
            "    contrast = 0.95\n"
            "}\n"
        )
    return "# generated by artwall.py — do not edit\n" + "\n".join(blocks)


def pango_escape(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def cmd_render(art: Artwork) -> None:
    ensure_fonts()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    mons = monitors()
    with Image.open(art.path) as im:
        painting = im.convert("RGB")
        # work at no more than 2x the largest canvas side; the source can be 10k+ px
        cap = 2 * max(max(m.width, m.height) for m in mons)
        if max(painting.size) > cap:
            painting = painting.resize(fit(painting.size, (cap, cap)), Image.Resampling.LANCZOS)
    for m in mons:
        captioned, plain = render_monitor(m, art, painting)
        atomic_save_image(captioned, CACHE_DIR / f"{m.name}.png")
        atomic_save_image(plain, CACHE_DIR / f"{m.name}-lock.png")
        log(f"rendered {m.name} {m.width}x{m.height}")
    thumb = painting.copy()
    thumb.thumbnail((512, 512))
    atomic_save_image(thumb, CACHE_DIR / "thumb.png")
    (CACHE_DIR / "hyprlock.conf").write_text(hyprlock_fragment(mons))
    (CACHE_DIR / "caption.txt").write_text(
        f"<i>{pango_escape(art.title)}</i>\n<span size='smaller'>{pango_escape(art.credit)}</span>\n"
    )
    save_json(CACHE_DIR / "current.json", asdict(art))


# ---------------------------------------------------------------------- setting


def awww_ready(wait: float = 15) -> bool:
    deadline = time.time() + wait
    while time.time() < deadline:
        try:
            if subprocess.run(["awww", "query"], capture_output=True, timeout=5).returncode == 0:
                return True
        except subprocess.TimeoutExpired:
            log("awww query hung; the daemon is wedged, restarting awww-daemon.service")
            subprocess.run(["systemctl", "--user", "restart", "awww-daemon.service"], check=False)
        time.sleep(0.5)
    return False


def apply_wallpaper() -> None:
    if not awww_ready(wait=10):
        # the daemon runs as a user service; revive it if it died
        log("awww-daemon not reachable, starting awww-daemon.service")
        subprocess.run(["systemctl", "--user", "start", "awww-daemon.service"], check=False)
        if not awww_ready(wait=15):
            log("awww-daemon is not running; rendered images only")
            return
    for m in monitors():
        img = CACHE_DIR / f"{m.name}.png"
        if img.exists():
            try:
                subprocess.run(["awww", "img", "-o", m.name, str(img), *TRANSITION], check=False, timeout=60)
            except subprocess.TimeoutExpired:
                log(f"awww img timed out for {m.name}")
    # A locked hyprlock picks the new image up on its own within reload_time (30 s).


def notify(art: Artwork) -> None:
    if shutil.which("notify-send"):
        subprocess.run(
            ["notify-send", "-a", "Artwall", "-i", str(CACHE_DIR / "thumb.png"),
             art.title, f"{art.credit}\n{art.source}"],
            check=False,
        )


def sync_colors(art: Artwork, mons: list[Monitor]) -> None:
    if not SYNC_COLORS or not shutil.which("qs") or not mons:
        return
    img = CACHE_DIR / f"{mons[0].name}-lock.png"
    subprocess.run(["qs", "ipc", "call", "theme", "generate", str(img)], check=False, capture_output=True)


# ---------------------------------------------------------------------- commands


def current() -> Artwork | None:
    d = load_json(CACHE_DIR / "current.json", None)
    return Artwork(**d) if d else None


def pick_next() -> Artwork | None:
    state = load_json(STATE_FILE, {})
    history: list[str] = state.get("history", [])
    blocked = blocklist()
    works = library()
    pool = [w for k, w in works.items() if k not in history and k not in blocked]
    if not pool:
        # everything has been shown: recycle the least recently shown ones
        pool = [works[k] for k in history if k in works and k not in blocked][: max(1, len(works) // 2)]
    if not pool:
        return None
    art = random.choice(pool)
    history = [h for h in history if h != art.id] + [art.id]
    state["history"] = history[-HISTORY_LEN:]
    state["current"] = art.id
    state["changed_at"] = time.time()
    save_json(STATE_FILE, state)
    return art


def cmd_next(force: bool = False) -> int:
    changed_at = load_json(STATE_FILE, {}).get("changed_at", 0)
    if not force and changed_at:
        age = time.time() - changed_at
        if age < MIN_INTERVAL:
            log(f"current painting is only {age / 60:.0f} min old; keeping it (use --force to skip)")
            return 0
    if not library():
        log("library is empty, fetching a first batch")
        cmd_refill(target=6)
    art = pick_next()
    if not art:
        log("no paintings available")
        return 1
    log(f"next: {art.title} — {art.credit} [{art.source}]")
    cmd_render(art)
    apply_wallpaper()
    notify(art)
    sync_colors(art, monitors())
    # top the library up in the background of this run so the next hour has fresh material
    try:
        cmd_refill()
    except Exception as e:
        log(f"refill skipped: {e}")
    return 0


def cmd_info() -> int:
    art = current()
    if not art:
        print("no artwork set")
        return 1
    print(f"{art.title}\n{art.credit}\n{art.source}\n{art.url}\n{art.path}")
    return 0


def cmd_block() -> int:
    art = current()
    if art:
        BLOCKLIST_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(BLOCKLIST_FILE, "a") as f:
            f.write(art.id + "\n")
        for p in (art.path, LIBRARY_DIR / f"{art.id}.json"):
            p.unlink(missing_ok=True)
        log(f"blocked {art.title}")
    return cmd_next(force=True)


def cmd_prune() -> int:
    """Drop museum pieces already in the library that fail the current vividness gate."""
    removed = 0
    for art in library().values():
        if art.source == "Wikimedia Commons":
            continue
        off_list = art.artist not in ARTISTS or EXCLUDE_TITLE.search(art.title)
        if off_list:
            log(f"rejected (not on the curated list): {art.title} — {art.artist}")
        if off_list or not vivid_enough(art.path):
            art.path.unlink(missing_ok=True)
            (LIBRARY_DIR / f"{art.id}.json").unlink(missing_ok=True)
            removed += 1
    log(f"pruned {removed}")
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "next"
    if cmd == "next":
        return cmd_next(force="--force" in argv)
    if cmd == "render":
        # re-render and re-apply the current painting (compositor restart, monitor change)
        art = current()
        if not art:
            return cmd_next()
        cmd_render(art)
        apply_wallpaper()
        return 0
    if cmd == "refill":
        cmd_refill(int(argv[2]) if len(argv) > 2 else TARGET_UNSEEN)
        return 0
    if cmd == "info":
        return cmd_info()
    if cmd == "block":
        return cmd_block()
    if cmd == "prune":
        return cmd_prune()
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

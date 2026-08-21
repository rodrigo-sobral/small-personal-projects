from __future__ import annotations

import logging
import queue
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from tkinter import font as tkfont

import yaml

from .client import FlyOrDieClient
from .domain import GameStats, PlayerProfile, RatingProjection, project
from .i18n import TEXT
from .logging_config import clear_log, configure_logging
from .paths import data_directory
from .storage import PlayerDataError, PlayerStore
from .widgets import AutoCompleteEntry

logger = logging.getLogger(__name__)

ICON_NAME = "favicon.ico"
ICON_CANDIDATES = (
    Path(__file__).resolve().parent / "assets" / ICON_NAME,
    Path(__file__).resolve().parents[2] / "assets" / ICON_NAME,
)
STAT_COLUMNS = ("rating", "matches", "wins", "draws", "losses")
TABLE_FONT = ("Avenir Next", 11)
# Cell text plus the room a Treeview needs for its own padding and sort marker.
COLUMN_PADDING = 26


def icon_path() -> Path | None:
    """Return the window icon, looking beside the package and in the project."""
    for candidate in ICON_CANDIDATES:
        if candidate.is_file():
            return candidate
    logger.warning("Window icon %s not found", ICON_NAME)
    return None


class App(tk.Tk):
    """Tkinter presentation layer; network work always runs away from Tk."""

    def __init__(self) -> None:
        super().__init__()
        self.client = FlyOrDieClient()
        self.store = PlayerStore()
        self.language = tk.StringVar(value="en")
        self.theme = tk.StringVar(value="light")
        self.status = tk.StringVar()
        self.player_profile: PlayerProfile | None = None
        self.left_profile: PlayerProfile | None = None
        self.right_profile: PlayerProfile | None = None
        self.current_games: dict[str, GameStats] = {}
        self._stat_rows: list[tuple[object, ...]] = []
        self._fitted_width = 0
        self.sort_column = "rating"
        self.sort_descending = True
        try:
            self.saved_profiles = self.store.load()
        except (OSError, ValueError, yaml.YAMLError) as exc:
            logger.warning("Could not load saved player data: %s", exc)
            self.saved_profiles = {}
        self._jobs: queue.Queue[callable] = queue.Queue()
        self.title("FlyOrDie")
        self._apply_icon()
        self.geometry("1080x760")
        self.minsize(900, 640)
        self._build()
        self._apply_theme()
        self._translate()
        self._refresh_saved_players()
        self.protocol("WM_DELETE_WINDOW", self._close)
        self.after(80, self._poll_jobs)

    def _apply_icon(self) -> None:
        """Set the window icon; only Windows Tk reads .ico files directly."""
        path = icon_path()
        if path is None:
            return
        try:
            if sys.platform == "win32":
                self.iconbitmap(str(path))
            else:
                from PIL import Image, ImageTk

                self._icon_image = ImageTk.PhotoImage(Image.open(path))
                self.iconphoto(True, self._icon_image)
        except (ImportError, OSError, tk.TclError) as exc:
            logger.warning("Could not set window icon from %s: %s", path, exc)

    def tr(self, key: str) -> str:
        return TEXT[self.language.get()][key]

    def _build(self) -> None:
        top = ttk.Frame(self, padding=(20, 16))
        top.pack(fill="x")
        self.title_label = ttk.Label(top, font=("Avenir Next", 22, "bold"))
        self.title_label.pack(side="left")
        self.clear_log_button = ttk.Button(top, command=self._clear_log)
        self.clear_log_button.pack(side="right")
        self.clear_cache_button = ttk.Button(top, command=self._clear_cache)
        self.clear_cache_button.pack(side="right", padx=8)
        self.theme_button = ttk.Button(top, command=self._toggle_theme)
        self.theme_button.pack(side="right")
        self.language_box = ttk.Combobox(top, state="readonly", width=11, values=("English", "Português"))

        self.language_box.current(0)
        self.language_box.bind("<<ComboboxSelected>>", lambda _: self._set_language())
        self.language_box.pack(side="right", padx=8)

        self.tabs = ttk.Notebook(self)
        self.tabs.pack(fill="both", expand=True, padx=20, pady=(0, 8))
        self.profile_tab = ttk.Frame(self.tabs, padding=20)
        self.compare_tab = ttk.Frame(self.tabs, padding=20)
        self.tabs.add(self.profile_tab, text="")
        self.tabs.add(self.compare_tab, text="")
        self._build_profile_tab()
        self._build_compare_tab()
        self.comboboxes = (self.language_box, self.game_box)
        ttk.Label(self, textvariable=self.status, anchor="w", padding=(20, 8)).pack(fill="x")

    def _build_profile_tab(self) -> None:
        form = ttk.Frame(self.profile_tab)
        form.pack(fill="x", pady=(0, 14))
        self.profile_prompt = ttk.Label(form)
        self.profile_prompt.pack(side="left")
        self.profile_name = ttk.Entry(form, width=30)
        self.profile_name.pack(side="left", padx=8)
        self.profile_name.bind("<Return>", lambda _: self._load_profile())
        self.profile_load = ttk.Button(form, command=self._load_profile)
        self.profile_load.pack(side="left")
        self.export_button = ttk.Button(form, command=self._export)
        self.export_button.pack(side="right")
        self.import_button = ttk.Button(form, command=self._import)
        self.import_button.pack(side="right", padx=8)
        self.profile_summary = ttk.Label(self.profile_tab, justify="left", padding=(0, 4))
        self.profile_summary.pack(anchor="w")
        panels = ttk.Frame(self.profile_tab)
        panels.pack(fill="both", expand=True, pady=(8, 0))
        self.saved_tree = self._saved_tree(panels)
        self.profile_tree = self._stats_tree(panels)

    def _saved_tree(self, parent: ttk.Frame) -> ttk.Treeview:
        tree = ttk.Treeview(parent, columns=("player",), show="headings", height=12, selectmode="browse")
        tree.column("player", width=180, anchor="w", stretch=False)
        tree.bind("<<TreeviewSelect>>", self._on_saved_selected)
        tree.bind("<Double-1>", self._on_saved_activated)
        tree.pack(side="left", fill="y", padx=(0, 12))
        return tree

    def _stats_tree(self, parent: ttk.Frame) -> ttk.Treeview:
        tree = ttk.Treeview(parent, columns=STAT_COLUMNS, show="headings", height=12)
        for column in STAT_COLUMNS:
            tree.heading(column, command=lambda name=column: self._sort_by(name))
            tree.column(column, anchor="w", stretch=True)
        tree.bind("<Configure>", self._on_stats_resized)
        tree.pack(side="left", fill="both", expand=True)
        return tree

    def _needed_widths(self, tree: ttk.Treeview, rows: list[tuple[object, ...]]) -> list[int]:
        measure = tkfont.Font(font=TABLE_FONT).measure
        heading_measure = tkfont.Font(font=(*TABLE_FONT, "bold")).measure
        widths = []
        for index, column in enumerate(tree["columns"]):
            # The sort marker is measured for every column so widths never jump.
            heading = heading_measure(f"{tree.heading(column, 'text').rstrip(' ▼▲')} ▼")
            widths.append(max([heading, *(measure(str(row[index])) for row in rows)]) + COLUMN_PADDING)
        return widths

    def _fit_saved_column(self, names: list[str]) -> None:
        """The saved list is a sidebar: it takes exactly the width it needs."""
        width = self._needed_widths(self.saved_tree, [(name,) for name in names])[0]
        self.saved_tree.column("player", width=width, minwidth=width)

    def _fit_columns(self, available: int | None = None) -> None:
        """Divide the visible table width between the columns, by content share."""
        needed = self._needed_widths(self.profile_tree, self._stat_rows)
        width = available if available is not None else self.profile_tree.winfo_width()
        if width <= 1:
            width = sum(needed)
        self._fitted_width = width
        # A share below 1 keeps the last column on screen instead of scrolling.
        share = width / sum(needed)
        for column, column_width in zip(self.profile_tree["columns"], needed):
            scaled = max(round(column_width * share), COLUMN_PADDING)
            self.profile_tree.column(column, width=scaled, minwidth=min(column_width, scaled))

    def _on_stats_resized(self, event: tk.Event) -> None:
        if event.width != self._fitted_width:
            self._fit_columns(event.width)

    def _build_compare_tab(self) -> None:
        form = ttk.Frame(self.compare_tab)
        form.pack(fill="x")
        self.left_prompt = ttk.Label(form)
        self.left_prompt.grid(row=0, column=0, sticky="w")
        self.left_name = self._compare_entry(form)
        self.left_name.grid(row=1, column=0, padx=(0, 12), pady=(4, 0))
        self.right_prompt = ttk.Label(form)
        self.right_prompt.grid(row=0, column=1, sticky="w")
        self.right_name = self._compare_entry(form)
        self.right_name.grid(row=1, column=1, padx=(0, 12), pady=(4, 0))
        controls = ttk.Frame(self.compare_tab, padding=(0, 18))
        controls.pack(fill="x")
        self.game_label = ttk.Label(controls)
        self.game_label.pack(side="left")
        self.game_box = ttk.Combobox(controls, state="readonly", width=22)
        self.game_box.pack(side="left", padx=(5, 16))
        self.simulate_button = ttk.Button(controls, command=self._simulate)
        self.simulate_button.pack(side="left", padx=12)
        self.result_cards = ttk.Frame(self.compare_tab)
        self.result_cards.pack(fill="x", pady=(8, 0))
        self.left_result = self._result_card(self.result_cards)
        self.left_result.pack(side="left", fill="both", expand=True, padx=(0, 8))
        self.right_result = self._result_card(self.result_cards)
        self.right_result.pack(side="left", fill="both", expand=True, padx=(8, 0))

    def _compare_entry(self, parent: ttk.Frame) -> AutoCompleteEntry:
        """This tab never reaches the network: it only reads saved players."""
        entry = AutoCompleteEntry(parent, width=24, on_select=lambda _: self._load_comparison())
        entry.bind("<FocusOut>", lambda _: self.after(200, self._load_comparison), add="+")
        return entry

    def _result_card(self, parent: ttk.Frame) -> ttk.LabelFrame:
        card = ttk.LabelFrame(parent, padding=16)
        card.title_label = ttk.Label(card, font=("Avenir Next", 13, "bold"))
        card.title_label.pack(anchor="w")
        card.probability_label = ttk.Label(card, font=("Avenir Next", 28, "bold"))
        card.probability_label.pack(anchor="w", pady=(8, 14))
        card.details_label = ttk.Label(card, justify="left")
        card.details_label.pack(anchor="w")
        return card

    def _set_language(self) -> None:
        self.language.set("en" if self.language_box.current() == 0 else "pt-PT")
        self._translate()
        self._refresh_saved_players()

    def _translate(self) -> None:
        self.title_label.config(text=self.tr("title"))
        self.tabs.tab(0, text=self.tr("profile")); self.tabs.tab(1, text=self.tr("compare"))
        self.profile_prompt.config(text=self.tr("player")); self.profile_load.config(text=self.tr("load")); self.export_button.config(text=self.tr("export")); self.import_button.config(text=self.tr("import"))
        self.saved_tree.heading("player", text=self.tr("known_players"))
        self.left_prompt.config(text=self.tr("player")); self.right_prompt.config(text=self.tr("opponent"))
        self.game_label.config(text=self.tr("game")); self.simulate_button.config(text=self.tr("simulate"))
        self.clear_cache_button.config(text=self.tr("clear_cache")); self.clear_log_button.config(text=self.tr("clear_log"))
        self.theme_button.config(text=self.tr("light") if self.theme.get() == "dark" else self.tr("dark"))
        self._label_stat_headings()
        self.status.set(self.tr("saved_hint") if self.saved_profiles else self.tr("ready"))

    def _label_stat_headings(self) -> None:
        for column in STAT_COLUMNS:
            marker = (" ▼" if self.sort_descending else " ▲") if column == self.sort_column else ""
            self.profile_tree.heading(column, text=f"{self.tr(column)}{marker}")

    def _refresh_saved_players(self) -> None:
        selected = self.saved_tree.selection()
        self.saved_tree.delete(*self.saved_tree.get_children())
        for name in sorted(self.saved_profiles, key=str.casefold):
            self.saved_tree.insert("", "end", iid=name, values=(name,))
        for name in selected:
            if self.saved_tree.exists(name):
                self.saved_tree.selection_set(name)
        names = sorted(self.saved_profiles, key=str.casefold)
        self._fit_saved_column(names)
        for entry in (self.left_name, self.right_name):
            entry.set_suggestions(names)

    def _on_saved_selected(self, _: tk.Event) -> None:
        selection = self.saved_tree.selection()
        profile = self.saved_profiles.get(selection[0]) if selection else None
        if profile is None:
            return
        self._display_profile(profile)
        self.status.set(f"{self.tr('showing_saved')} {profile.name}")

    def _on_saved_activated(self, _: tk.Event) -> None:
        selection = self.saved_tree.selection()
        if selection:
            self._fetch(selection[0])

    def _toggle_theme(self) -> None:
        self.theme.set("light" if self.theme.get() == "dark" else "dark")
        self._apply_theme(); self._translate()

    def _apply_theme(self) -> None:
        dark = self.theme.get() == "dark"
        bg, fg, field, accent = (("#17212b", "#f4f7fb", "#243443", "#3aa6b9") if dark else ("#f4f1ea", "#17212b", "#ffffff", "#197278"))
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure(".", background=bg, foreground=fg, font=("Avenir Next", 11))
        style.configure("TFrame", background=bg); style.configure("TLabel", background=bg, foreground=fg)
        style.configure("TButton", padding=(10, 7), background=accent, foreground="#ffffff", borderwidth=0)
        style.map("TButton", background=[("active", "#0f5961")])
        # insertcolor keeps the text cursor visible; clam defaults it to black.
        style.configure("TEntry", fieldbackground=field, foreground=fg, padding=6, insertcolor=fg, insertwidth=2, bordercolor=field)
        style.map("TEntry", bordercolor=[("focus", accent)], lightcolor=[("focus", accent)], darkcolor=[("focus", accent)])
        self._style_comboboxes(style, fg, field, accent)
        # clam keeps a dark tab label whatever the background, so set both.
        style.configure("TNotebook", background=bg, borderwidth=0)
        style.configure("TNotebook.Tab", background=field, foreground=fg, padding=(14, 8), borderwidth=0)
        style.map(
            "TNotebook.Tab",
            background=[("selected", accent), ("active", accent)],
            foreground=[("selected", "#ffffff"), ("active", "#ffffff")],
            expand=[("selected", (0, 0, 0, 0))],
        )
        style.configure("Treeview", background=field, fieldbackground=field, foreground=fg, rowheight=30, borderwidth=0)
        style.configure("Treeview.Heading", background=accent, foreground="#ffffff", padding=8)
        style.map("Treeview", background=[("selected", accent)], foreground=[("selected", "#ffffff")])
        style.configure("TLabelframe", background=field, foreground=fg)
        style.configure("TLabelframe.Label", background=field, foreground=fg)
        self.configure(background=bg)
        for entry in (self.left_name, self.right_name):
            entry.style_suggestions(background=field, foreground=fg, selectbackground=accent, selectforeground="#ffffff")

    def _style_comboboxes(self, style: ttk.Style, fg: str, field: str, accent: str) -> None:
        """Readonly comboboxes and their popups need explicit colours in clam."""
        style.configure("TCombobox", fieldbackground=field, background=field, foreground=fg, arrowcolor=fg, padding=4)
        style.map(
            "TCombobox",
            fieldbackground=[("readonly", field), ("disabled", field)],
            background=[("readonly", field), ("active", field)],
            foreground=[("readonly", fg), ("disabled", fg)],
            selectbackground=[("readonly", field), ("focus", field)],
            selectforeground=[("readonly", fg), ("focus", fg)],
            arrowcolor=[("readonly", fg), ("active", accent)],
        )
        for option, value in (
            ("*TCombobox*Listbox.background", field),
            ("*TCombobox*Listbox.foreground", fg),
            ("*TCombobox*Listbox.selectBackground", accent),
            ("*TCombobox*Listbox.selectForeground", "#ffffff"),
        ):
            self.option_add(option, value)
        # Popups created before this call keep their old colours, so repaint them.
        for box in getattr(self, "comboboxes", ()):
            listbox = f"{box}.popdown.f.l"
            if self.tk.call("winfo", "exists", listbox):
                self.tk.call(listbox, "configure", "-background", field, "-foreground", fg,
                             "-selectbackground", accent, "-selectforeground", "#ffffff")

    def _run(self, task: callable, success: callable) -> None:
        self.status.set(self.tr("loading"))
        def worker() -> None:
            try:
                value = task()
            except Exception as exc:
                logger.exception("Background user request failed")
                self._jobs.put(lambda error=exc: self._show_error(error))
            else:
                self._jobs.put(lambda: success(value))
        threading.Thread(target=worker, daemon=True).start()

    def _poll_jobs(self) -> None:
        try:
            while True:
                self._jobs.get_nowait()()
        except queue.Empty:
            pass
        self.after(80, self._poll_jobs)

    def _show_error(self, error: Exception) -> None:
        messagebox.showerror(self.tr("error"), str(error)); self.status.set(self.tr("ready"))

    def _load_profile(self) -> None:
        self._fetch(self.profile_name.get())

    def _fetch(self, name: str) -> None:
        self._run(lambda: self.client.profile(name), self._show_profile)

    def _show_profile(self, profile: PlayerProfile) -> None:
        self.saved_profiles = self.store.merge(profile)
        self._refresh_saved_players()
        if self.saved_tree.exists(profile.name):
            self.saved_tree.selection_set(profile.name)
        self._display_profile(profile)
        self.status.set(self.tr("saved"))

    def _display_profile(self, profile: PlayerProfile) -> None:
        self.player_profile = profile
        details = [f"{self.tr(label)}: {value}" for label, value in (("country", profile.country), ("age", profile.age), ("status", profile.status), ("room", profile.room)) if value]
        self.profile_summary.config(text=" · ".join(details))
        self.current_games = profile.games
        self._fill_tree()

    def _sort_by(self, column: str) -> None:
        """First click on a column sorts descending, the next one ascending."""
        if column == self.sort_column:
            self.sort_descending = not self.sort_descending
        else:
            self.sort_column, self.sort_descending = column, True
        self._label_stat_headings()
        self._fill_tree()

    def _fill_tree(self) -> None:
        self.profile_tree.delete(*self.profile_tree.get_children())
        self._stat_rows = [
            (f"{slug} ({game.rating or '-'})", game.matches or "-", game.wins or "-", game.draws or "-", game.losses or "-")
            for slug, game in self._sorted_games()
        ]
        for row in self._stat_rows:
            self.profile_tree.insert("", "end", values=row)
        self._fit_columns()

    def _sorted_games(self) -> list[tuple[str, GameStats]]:
        items = sorted(self.current_games.items())
        rated = [item for item in items if getattr(item[1], self.sort_column) is not None]
        rated.sort(key=lambda item: (getattr(item[1], self.sort_column), item[0].casefold()), reverse=self.sort_descending)
        # Games without the sorted value stay at the end in both directions.
        return rated + [item for item in items if getattr(item[1], self.sort_column) is None]

    def _export(self) -> None:
        if not self.saved_profiles:
            return
        path = filedialog.asksaveasfilename(defaultextension=".yaml", filetypes=[("YAML", "*.yaml")], initialfile="players.yaml")
        if path:
            try:
                PlayerStore(Path(path)).save(self.saved_profiles)
            except OSError as exc:
                logger.exception("Could not export player data")
                self._show_error(exc)
            else:
                self.status.set(self.tr("saved"))

    def _import(self) -> None:
        """Merge a chosen YAML file: keep current players, overwrite repeats."""
        path = filedialog.askopenfilename(filetypes=[("YAML", "*.yaml *.yml"), ("All files", "*.*")])
        if not path:
            return
        try:
            imported = PlayerStore(Path(path)).read_validated()
        except (OSError, PlayerDataError) as exc:
            logger.warning("Rejected imported player file %s: %s", path, exc)
            self._show_error(exc)
            return
        merged = dict(self.saved_profiles)
        for name, profile in imported.items():
            for existing in [key for key in merged if key.casefold() == name.casefold()]:
                del merged[existing]
            merged[name] = profile
        try:
            self.store.save(merged)
        except OSError as exc:
            logger.exception("Could not save imported player data")
            self._show_error(exc)
            return
        self.saved_profiles = merged
        self._refresh_saved_players()
        logger.info("Imported %d player(s) from a YAML file", len(imported))
        self.status.set(f"{self.tr('imported')}: {len(imported)}")

    def _clear_cache(self) -> None:
        self.client.clear_cache(); self.status.set(self.tr("cache_cleared"))

    def _clear_log(self) -> None:
        clear_log(); self.status.set(self.tr("log_cleared"))

    def _saved_profile(self, name: str) -> PlayerProfile | None:
        return next((profile for key, profile in self.saved_profiles.items() if key.casefold() == name.casefold()), None)

    def _load_comparison(self) -> None:
        """Compare from saved data only; fetching happens in Player statistics."""
        left_name, right_name = self.left_name.get_text(), self.right_name.get_text()
        if not left_name or not right_name:
            return
        self.left_profile, self.right_profile = self._saved_profile(left_name), self._saved_profile(right_name)
        missing = [name for name, profile in ((left_name, self.left_profile), (right_name, self.right_profile)) if profile is None]
        self._clear_results()
        if missing:
            self.game_box.set(""); self.game_box["values"] = ()
            self.status.set(f"{self.tr('not_saved')} {', '.join(missing)}")
            return
        shared = sorted(set(self.left_profile.games) & set(self.right_profile.games))
        self.game_box["values"] = shared
        if shared:
            self.game_box.current(0)
            self.status.set(self.tr("ready"))
        else:
            self.game_box.set("")
            self.status.set(self.tr("no_shared"))

    def _clear_results(self) -> None:
        for card in (self.left_result, self.right_result):
            card.title_label.config(text=""); card.probability_label.config(text=""); card.details_label.config(text="")

    def _simulate(self) -> None:
        if not self.left_profile or not self.right_profile or not self.game_box.get(): return
        game = self.game_box.get()
        left, right = self.left_profile.games[game], self.right_profile.games[game]
        if left.rating is None or right.rating is None: return
        outcomes = (project(left.rating, right.rating), project(right.rating, left.rating))
        self._show_result_card(self.left_result, self.left_profile.name, outcomes[0])
        self._show_result_card(self.right_result, self.right_profile.name, outcomes[1])

    def _show_result_card(self, card: ttk.LabelFrame, name: str, result: RatingProjection) -> None:
        card.title_label.config(text=name)
        card.probability_label.config(text=f"{result.probability:.1%}")
        card.details_label.config(text=(f"{self.tr('chance')}\n\n{self.tr('on_win')}: {result.win_rating}\n{self.tr('on_draw')}: {result.draw_rating}\n{self.tr('on_loss')}: {result.loss_rating}\n\n{self.tr('decay')}: {result.zero_date.isoformat()}\n{result.zero_days} {self.tr('days')}"))

    def _close(self) -> None:
        logger.info("Application closed by user")
        self.destroy()


def main() -> None:
    configure_logging(data_directory())
    logger.info("Application starting")
    App().mainloop()

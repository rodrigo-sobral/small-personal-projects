"""Reusable Tkinter widgets kept out of the main presentation module."""

from __future__ import annotations

import tkinter as tk
from collections.abc import Callable, Iterable
from tkinter import ttk

MAX_SUGGESTIONS = 8


class AutoCompleteEntry(ttk.Entry):
    """Entry that offers matching names from a suggestion list.

    The suggestion list is drawn inside the containing window instead of a
    separate popup window, which keeps focus behaviour predictable on macOS.
    """

    def __init__(
        self,
        master: tk.Misc,
        suggestions: Iterable[str] = (),
        on_select: Callable[[str], None] | None = None,
        **kwargs: object,
    ) -> None:
        self.variable: tk.StringVar = kwargs.pop("textvariable", None) or tk.StringVar()
        super().__init__(master, textvariable=self.variable, **kwargs)
        self.suggestions = sorted(suggestions, key=str.casefold)
        self.on_select = on_select
        self._colors: dict[str, str] = {}
        self._list: tk.Listbox | None = None
        self.bind("<KeyRelease>", self._on_key_release)
        self.bind("<Down>", self._on_arrow)
        self.bind("<Up>", self._on_arrow)
        self.bind("<Return>", self._on_return)
        self.bind("<Escape>", lambda _: self.hide())
        # An empty field offers every known name.
        self.bind("<FocusIn>", lambda _: self._reveal())
        self.bind("<Button-1>", lambda _: self.after_idle(self._reveal))
        # A late hide lets a click on the list register before it disappears.
        self.bind("<FocusOut>", lambda _: self.after(150, self.hide))

    def set_suggestions(self, suggestions: Iterable[str]) -> None:
        self.suggestions = sorted(suggestions, key=str.casefold)

    def style_suggestions(self, **colors: str) -> None:
        """Store popup colours so the list follows the active theme."""
        self._colors = colors
        if self._list is not None:
            self._list.configure(**colors)

    def get_text(self) -> str:
        return self.variable.get().strip()

    def hide(self) -> None:
        if self._list is not None:
            self._list.place_forget()

    def _visible(self) -> bool:
        return self._list is not None and bool(self._list.winfo_ismapped())

    def _matches(self) -> list[str]:
        """Names to offer: everything while the field is empty, matches after."""
        text = self.get_text().casefold()
        if not text:
            return list(self.suggestions)
        starts = [name for name in self.suggestions if name.casefold().startswith(text)]
        contains = [name for name in self.suggestions if text in name.casefold() and name not in starts]
        return starts + contains

    def _reveal(self) -> None:
        matches = self._matches()
        self._show(matches) if matches else self.hide()

    def _on_key_release(self, event: tk.Event) -> None:
        if event.keysym in {"Up", "Down", "Return", "Escape", "Tab"}:
            return
        self._reveal()

    def _show(self, matches: list[str]) -> None:
        window = self.winfo_toplevel()
        if self._list is None:
            self._list = tk.Listbox(window, activestyle="none", exportselection=False, borderwidth=1, highlightthickness=0)
            self._list.bind("<ButtonRelease-1>", self._on_click)
            if self._colors:
                self._list.configure(**self._colors)
        self._list.delete(0, "end")
        for match in matches:
            self._list.insert("end", match)
        # A long list keeps every name; the arrow keys scroll through it.
        self._list.configure(height=min(len(matches), MAX_SUGGESTIONS))
        self._list.place(
            x=self.winfo_rootx() - window.winfo_rootx(),
            y=self.winfo_rooty() - window.winfo_rooty() + self.winfo_height(),
            width=self.winfo_width(),
        )
        self._list.lift()

    def _on_arrow(self, event: tk.Event) -> str:
        """Move the highlight without moving focus, so typing stays possible."""
        if not self._visible():
            self._reveal()
        if not self._visible():
            return "break"
        last = self._list.size() - 1
        current = self._list.curselection()
        if not current:
            index = 0 if event.keysym == "Down" else last
        else:
            index = max(0, min(current[0] + (1 if event.keysym == "Down" else -1), last))
        self._list.selection_clear(0, "end")
        self._list.selection_set(index)
        self._list.activate(index)
        self._list.see(index)
        return "break"

    def _on_click(self, _: tk.Event) -> None:
        nearest = self._list.nearest(self._list.winfo_pointery() - self._list.winfo_rooty())
        self._commit(self._list.get(nearest))

    def _on_return(self, _: tk.Event) -> str:
        selection = self._list.curselection() if self._visible() else ()
        self._commit(self._list.get(selection[0]) if selection else self.get_text())
        return "break"

    def _commit(self, value: str) -> None:
        self.variable.set(value)
        self.hide()
        self.focus_set()
        self.icursor("end")
        if self.on_select is not None and value:
            self.on_select(value)

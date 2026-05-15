#!/usr/bin/python3
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import subprocess, urllib.request, tempfile, os

CSS = b"""
* { outline: none; box-shadow: none; }
window {
    background-color: rgba(17, 17, 27, 0.97);
    border-radius: 16px;
    border: 1px solid rgba(203, 166, 247, 0.18);
    color: #cdd6f4;
}
.header-label { font-size: 13px; font-weight: bold; color: #cdd6f4; padding: 14px 16px 4px 16px; }
.section-label { font-size: 10px; font-weight: bold; color: #6c7086; letter-spacing: 1px; padding: 10px 16px 4px 16px; }
.card { background-color: rgba(49,50,68,0.55); border-radius: 14px; margin: 3px 10px; padding: 10px 14px; border: 1px solid rgba(255,255,255,0.04); }
.stream-card { background-color: rgba(49,50,68,0.4); border-radius: 10px; margin: 2px 10px; padding: 6px 12px; }
.vol-label { font-size: 12px; color: #cba6f7; font-weight: bold; min-width: 42px; }
.device-name { font-size: 12px; color: #cdd6f4; font-weight: 500; }
.app-name { font-size: 11px; color: #6c7086; }
.track-title { font-size: 13px; font-weight: bold; color: #cdd6f4; }
.track-artist { font-size: 11px; color: #6c7086; }
.mute-btn { background-color: rgba(203,166,247,0.12); color: #cba6f7; border: 1px solid rgba(203,166,247,0.2); border-radius: 50px; padding: 4px 10px; font-size: 15px; min-width: 36px; }
.ctrl-btn { background-color: rgba(49,50,68,0.7); color: #cdd6f4; border: 1px solid rgba(255,255,255,0.08); border-radius: 50px; padding: 5px 14px; font-size: 15px; min-width: 38px; }
.ctrl-btn-play { background-color: rgba(203,166,247,0.22); color: #cba6f7; border: 1px solid rgba(203,166,247,0.4); border-radius: 50px; padding: 5px 18px; font-size: 17px; min-width: 46px; }
scale trough { background-color: rgba(49,50,68,0.9); border-radius: 4px; min-height: 4px; }
scale highlight { background-color: #cba6f7; border-radius: 4px; }
scale slider { background-color: #cba6f7; border-radius: 50%; min-width: 14px; min-height: 14px; margin: -5px 0; }
"""

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode().strip()
    except:
        return ""

def get_volume():
    out = run(['pactl', 'get-sink-volume', '@DEFAULT_SINK@'])
    try:
        return int(out.split('/')[1].strip().replace('%', ''))
    except:
        return 50

def set_volume(val):
    subprocess.Popen(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', f'{int(val)}%'])

def get_muted():
    return 'yes' in run(['pactl', 'get-sink-mute', '@DEFAULT_SINK@'])

def get_sink_name():
    sink = run(['pactl', 'get-default-sink'])
    found = False
    for line in run(['pactl', 'list', 'sinks']).split('\n'):
        if f'Name: {sink}' in line:
            found = True
        if found and 'Description:' in line:
            return line.split('Description:', 1)[1].strip()
    return sink or "Default Output"

def get_sink_inputs():
    inputs = []
    for block in run(['pactl', 'list', 'sink-inputs']).split('Sink Input #')[1:]:
        name, vol = "", 0
        for line in block.split('\n'):
            if 'application.name' in line:
                name = line.split('=', 1)[-1].strip().strip('"')
            if 'Volume:' in line and 'Base Volume' not in line and '%' in line:
                try:
                    vol = int(line.split('/')[1].strip().replace('%', ''))
                except:
                    pass
        if name:
            inputs.append((name, vol))
    return inputs

def get_album_art():
    art_url = run(['playerctl', 'metadata', 'mpris:artUrl'])
    if not art_url:
        return None
    try:
        if art_url.startswith('file://'):
            return art_url[7:]
        elif art_url.startswith('http'):
            tmp = tempfile.NamedTemporaryFile(suffix='.jpg', delete=False)
            urllib.request.urlretrieve(art_url, tmp.name)
            return tmp.name
    except:
        pass
    return None


class SoundPopup(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("Sound")
        self.set_default_size(340, -1)
        self.set_resizable(False)
        self.set_decorated(False)

        css = Gtk.CssProvider()
        css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        focus = Gtk.EventControllerFocus()
        focus.connect('leave', lambda *a: self.close())
        self.add_controller(focus)

        key = Gtk.EventControllerKey()
        key.connect('key-pressed', lambda c, k, *a: self.close() if k == Gdk.KEY_Escape else False)
        self.add_controller(key)

        self.build_ui()

    def build_ui(self):
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_max_content_height(600)
        scroll.set_propagate_natural_height(True)
        self.set_child(scroll)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        scroll.set_child(box)

        hdr = Gtk.Label(label="󰕾  Sound")
        hdr.add_css_class("header-label"); hdr.set_halign(Gtk.Align.START)
        box.append(hdr)

        dev_lbl = Gtk.Label(label="OUTPUT")
        dev_lbl.add_css_class("section-label"); dev_lbl.set_halign(Gtk.Align.START)
        box.append(dev_lbl)

        vol_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        vol_card.add_css_class("card")

        sink_lbl = Gtk.Label(label=get_sink_name())
        sink_lbl.add_css_class("device-name"); sink_lbl.set_halign(Gtk.Align.START); sink_lbl.set_ellipsize(3)
        vol_card.append(sink_lbl)

        vol_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.mute_btn = Gtk.Button(label="󰝟" if get_muted() else "󰕾")
        self.mute_btn.add_css_class("mute-btn")
        self.mute_btn.connect('clicked', self.on_mute)
        vol_row.append(self.mute_btn)

        self.vol_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.vol_scale.set_value(get_volume()); self.vol_scale.set_hexpand(True); self.vol_scale.set_draw_value(False)
        self.vol_scale.connect('value-changed', self.on_vol_change)
        vol_row.append(self.vol_scale)

        self.vol_pct = Gtk.Label(label=f"{get_volume()}%")
        self.vol_pct.add_css_class("vol-label")
        vol_row.append(self.vol_pct)
        vol_card.append(vol_row)
        box.append(vol_card)

        inputs = get_sink_inputs()
        if inputs:
            apps_lbl = Gtk.Label(label="APPS")
            apps_lbl.add_css_class("section-label"); apps_lbl.set_halign(Gtk.Align.START)
            box.append(apps_lbl)
            for name, vol in inputs:
                sc = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                sc.add_css_class("stream-card")
                an = Gtk.Label(label=name); an.add_css_class("app-name"); an.set_halign(Gtk.Align.START)
                sc.append(an)
                sr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                s = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
                s.set_value(vol); s.set_hexpand(True); s.set_draw_value(False); s.set_sensitive(False)
                sr.append(s)
                p = Gtk.Label(label=f"{vol}%"); p.add_css_class("vol-label"); sr.append(p)
                sc.append(sr); box.append(sc)

        title = run(['playerctl', 'metadata', 'title'])
        artist = run(['playerctl', 'metadata', 'artist'])
        status = run(['playerctl', 'status'])

        if title:
            np_lbl = Gtk.Label(label="NOW PLAYING")
            np_lbl.add_css_class("section-label"); np_lbl.set_halign(Gtk.Align.START)
            box.append(np_lbl)

            np_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            np_card.add_css_class("card")

            art_path = get_album_art()
            if art_path and os.path.exists(art_path):
                try:
                    art = Gtk.Picture.new_for_filename(art_path)
                    art.set_size_request(56, 56); art.set_can_shrink(True)
                    art.set_content_fit(Gtk.ContentFit.COVER); art.set_valign(Gtk.Align.CENTER)
                    np_card.append(art)
                except:
                    pass

            right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            right.set_hexpand(True); right.set_valign(Gtk.Align.CENTER)

            tl = Gtk.Label(label=title[:30] + ("…" if len(title) > 30 else ""))
            tl.add_css_class("track-title"); tl.set_halign(Gtk.Align.START)
            right.append(tl)

            if artist:
                al = Gtk.Label(label=artist[:32] + ("…" if len(artist) > 32 else ""))
                al.add_css_class("track-artist"); al.set_halign(Gtk.Align.START)
                right.append(al)

            ctrl = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            ctrl.set_halign(Gtk.Align.START)

            pb = Gtk.Button(label="󰒮"); pb.add_css_class("ctrl-btn")
            pb.connect('clicked', lambda b: subprocess.Popen(['playerctl', 'previous']))
            ctrl.append(pb)

            self.play_btn = Gtk.Button(label="󰏤" if status == "Playing" else "󰐊")
            self.play_btn.add_css_class("ctrl-btn-play")
            self.play_btn.connect('clicked', self.on_play_pause)
            ctrl.append(self.play_btn)

            nb = Gtk.Button(label="󰒭"); nb.add_css_class("ctrl-btn")
            nb.connect('clicked', lambda b: subprocess.Popen(['playerctl', 'next']))
            ctrl.append(nb)

            right.append(ctrl); np_card.append(right); box.append(np_card)

        pad = Gtk.Box(); pad.set_size_request(-1, 10); box.append(pad)

    def on_vol_change(self, scale):
        val = int(scale.get_value())
        self.vol_pct.set_label(f"{val}%")
        set_volume(val)

    def on_mute(self, btn):
        subprocess.Popen(['pactl', 'set-sink-mute', '@DEFAULT_SINK@', 'toggle'])
        GLib.timeout_add(100, lambda: (btn.set_label("󰝟" if get_muted() else "󰕾"), False)[1])

    def on_play_pause(self, btn):
        subprocess.Popen(['playerctl', 'play-pause'])
        GLib.timeout_add(150, lambda: (self.play_btn.set_label("󰏤" if run(['playerctl','status'])=="Playing" else "󰐊"), False)[1])


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='com.hypr.soundpopup')
    def do_activate(self):
        SoundPopup(self).present()

App().run()

#!/usr/bin/python3
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
gi.require_version('NM', '1.0')
from gi.repository import Gtk, Gdk, NM, GLib
import subprocess

def decode_ssid(raw):
    if raw is None:
        return None
    try:
        d = raw.get_data()
        if isinstance(d, (bytes, bytearray)):
            return d.decode('utf-8', errors='replace')
        return bytes(d).decode('utf-8', errors='replace')
    except:
        return str(raw)

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
.toggle-row { background-color: rgba(49,50,68,0.55); border-radius: 14px; margin: 3px 10px; padding: 10px 14px; border: 1px solid rgba(255,255,255,0.04); }
.toggle-label { font-size: 13px; font-weight: 500; color: #cdd6f4; }
.toggle-sub { font-size: 11px; color: #6c7086; }
.network-row { background-color: rgba(49,50,68,0.4); border-radius: 10px; margin: 2px 10px; padding: 8px 12px; }
.network-row-active { background-color: rgba(166,227,161,0.1); border-radius: 10px; margin: 2px 10px; padding: 8px 12px; border: 1px solid rgba(166,227,161,0.2); }
.network-name { font-size: 13px; color: #cdd6f4; font-weight: 500; }
.network-info { font-size: 11px; color: #6c7086; }
.connected-info { font-size: 11px; color: #a6e3a1; }
.signal-icon { font-size: 16px; color: #cba6f7; min-width: 24px; }
.btn-disconnect { background-color: rgba(243,139,168,0.12); color: #f38ba8; border: 1px solid rgba(243,139,168,0.25); border-radius: 8px; padding: 3px 10px; font-size: 11px; }
.btn-connect { background-color: rgba(203,166,247,0.12); color: #cba6f7; border: 1px solid rgba(203,166,247,0.25); border-radius: 8px; padding: 3px 10px; font-size: 11px; }
.btn-scan { background-color: rgba(49,50,68,0.5); color: #cdd6f4; border: 1px solid rgba(255,255,255,0.06); border-radius: 10px; padding: 8px; margin: 6px 10px 10px 10px; font-size: 12px; }
switch:checked { background-color: #cba6f7; }
"""

def sig_icon(s):
    if s >= 75: return "󰤨"
    elif s >= 50: return "󰤥"
    elif s >= 25: return "󰤢"
    return "󰤟"

class WifiPopup(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("WiFi")
        self.set_default_size(320, -1)
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
        self.client = NM.Client.new(None)
        self.build_ui()

    def get_active_ssid_signal(self):
        for conn in self.client.get_active_connections():
            devs = conn.get_devices()
            if devs and devs[0].get_device_type() == NM.DeviceType.WIFI:
                ap = devs[0].get_active_access_point()
                if ap and ap.get_ssid():
                    return decode_ssid(ap.get_ssid()), ap.get_strength()
        return None, 0

    def get_wifi_enabled(self):
        for dev in self.client.get_devices():
            if dev.get_device_type() == NM.DeviceType.WIFI:
                return dev.get_state() not in (NM.DeviceState.UNAVAILABLE, NM.DeviceState.UNMANAGED)
        return False

    def get_aps(self):
        seen = {}
        for dev in self.client.get_devices():
            if dev.get_device_type() == NM.DeviceType.WIFI:
                for ap in dev.get_access_points():
                    if not ap.get_ssid():
                        continue
                    ssid = decode_ssid(ap.get_ssid())
                    if ssid and (ssid not in seen or ap.get_strength() > seen[ssid]):
                        seen[ssid] = ap.get_strength()
        return sorted(seen.items(), key=lambda x: x[1], reverse=True)

    def build_ui(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(outer)
        hdr = Gtk.Label(label="󰤨  WiFi")
        hdr.add_css_class("header-label"); hdr.set_halign(Gtk.Align.START)
        outer.append(hdr)
        toggle_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        toggle_row.add_css_class("toggle-row")
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        info.set_hexpand(True)
        tl = Gtk.Label(label="Wi-Fi"); tl.add_css_class("toggle-label"); tl.set_halign(Gtk.Align.START)
        ts = Gtk.Label(label="Find and connect to networks"); ts.add_css_class("toggle-sub"); ts.set_halign(Gtk.Align.START)
        info.append(tl); info.append(ts)
        toggle_row.append(info)
        self.wifi_switch = Gtk.Switch()
        self.wifi_switch.set_active(self.get_wifi_enabled())
        self.wifi_switch.set_valign(Gtk.Align.CENTER)
        self.wifi_switch.connect('notify::active', self.on_wifi_toggle)
        toggle_row.append(self.wifi_switch)
        outer.append(toggle_row)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_max_content_height(320)
        scroll.set_propagate_natural_height(True)
        self.net_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        scroll.set_child(self.net_box)
        outer.append(scroll)
        self.populate_networks()
        scan = Gtk.Button(label="󰑐  Scan for Networks")
        scan.add_css_class("btn-scan")
        scan.connect('clicked', self.on_scan)
        outer.append(scan)

    def populate_networks(self):
        while self.net_box.get_first_child():
            self.net_box.remove(self.net_box.get_first_child())
        active_ssid, active_signal = self.get_active_ssid_signal()
        if active_ssid:
            lbl = Gtk.Label(label="CONNECTED"); lbl.add_css_class("section-label"); lbl.set_halign(Gtk.Align.START)
            self.net_box.append(lbl)
            self.net_box.append(self.make_row(active_ssid, active_signal, True))
        aps = [(s, sig) for s, sig in self.get_aps() if s != active_ssid]
        if aps:
            lbl2 = Gtk.Label(label="AVAILABLE"); lbl2.add_css_class("section-label"); lbl2.set_halign(Gtk.Align.START)
            self.net_box.append(lbl2)
            for ssid, strength in aps[:12]:
                self.net_box.append(self.make_row(ssid, strength, False))
        return False

    def make_row(self, ssid, strength, connected):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row.add_css_class("network-row-active" if connected else "network-row")
        sig = Gtk.Label(label=sig_icon(strength)); sig.add_css_class("signal-icon")
        row.append(sig)
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        info.set_hexpand(True)
        n = Gtk.Label(label=ssid); n.add_css_class("network-name"); n.set_halign(Gtk.Align.START); n.set_ellipsize(3)
        info.append(n)
        s = Gtk.Label(label=f"Connected · {strength}%" if connected else f"{strength}% signal")
        s.add_css_class("connected-info" if connected else "network-info"); s.set_halign(Gtk.Align.START)
        info.append(s); row.append(info)
        if connected:
            btn = Gtk.Button(label="Disconnect"); btn.add_css_class("btn-disconnect")
            btn.connect('clicked', lambda b: (subprocess.Popen(['nmcli', 'dev', 'disconnect', 'wlan0']), GLib.timeout_add(800, self.populate_networks)))
        else:
            btn = Gtk.Button(label="Connect"); btn.add_css_class("btn-connect")
            btn.connect('clicked', lambda b, ss=ssid: (subprocess.Popen(['nmcli', 'dev', 'wifi', 'connect', ss]), GLib.timeout_add(1500, self.populate_networks)))
        row.append(btn)
        return row

    def on_wifi_toggle(self, switch, *args):
        subprocess.Popen(['nmcli', 'radio', 'wifi', 'on' if switch.get_active() else 'off'])
        GLib.timeout_add(600, self.populate_networks)

    def on_scan(self, btn):
        subprocess.Popen(['nmcli', 'dev', 'wifi', 'rescan'])
        GLib.timeout_add(2000, self.populate_networks)

class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='com.hypr.wifipopup')
    def do_activate(self):
        WifiPopup(self).present()

App().run()

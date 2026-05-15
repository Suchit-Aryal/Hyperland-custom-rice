#!/usr/bin/python3
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import subprocess

CSS = b"""
* { outline: none; box-shadow: none; }
window {
    background-color: rgba(17, 17, 27, 0.97);
    border-radius: 16px;
    border: 1px solid rgba(137, 180, 250, 0.18);
    color: #cdd6f4;
}
.header-label { font-size: 13px; font-weight: bold; color: #cdd6f4; padding: 14px 16px 4px 16px; }
.section-label { font-size: 10px; font-weight: bold; color: #6c7086; letter-spacing: 1px; padding: 10px 16px 4px 16px; }
.toggle-row { background-color: rgba(49,50,68,0.55); border-radius: 14px; margin: 3px 10px; padding: 10px 14px; border: 1px solid rgba(255,255,255,0.04); }
.toggle-label { font-size: 13px; font-weight: 500; color: #cdd6f4; }
.toggle-sub { font-size: 11px; color: #6c7086; }
.device-row { background-color: rgba(49,50,68,0.4); border-radius: 10px; margin: 2px 10px; padding: 9px 12px; }
.device-row-connected { background-color: rgba(137,180,250,0.1); border-radius: 10px; margin: 2px 10px; padding: 9px 12px; border: 1px solid rgba(137,180,250,0.2); }
.device-name { font-size: 13px; color: #cdd6f4; font-weight: 500; }
.device-info { font-size: 11px; color: #6c7086; }
.device-info-connected { font-size: 11px; color: #89b4fa; }
.device-icon { font-size: 18px; color: #89b4fa; min-width: 28px; }
.btn-disconnect { background-color: rgba(243,139,168,0.12); color: #f38ba8; border: 1px solid rgba(243,139,168,0.25); border-radius: 8px; padding: 3px 10px; font-size: 11px; }
.btn-connect { background-color: rgba(137,180,250,0.12); color: #89b4fa; border: 1px solid rgba(137,180,250,0.25); border-radius: 8px; padding: 3px 10px; font-size: 11px; }
.btn-scan { background-color: rgba(49,50,68,0.5); color: #cdd6f4; border: 1px solid rgba(255,255,255,0.06); border-radius: 10px; padding: 8px; margin: 6px 10px 10px 10px; font-size: 12px; }
.no-devices { font-size: 12px; color: #6c7086; padding: 12px 16px; }
switch:checked { background-color: #89b4fa; }
"""

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode().strip()
    except:
        return ""

def get_bt_devices():
    devices = []
    for line in run(['bluetoothctl', 'devices']).splitlines():
        parts = line.split(' ', 2)
        if len(parts) < 3:
            continue
        mac, name = parts[1], parts[2]
        info = run(['bluetoothctl', 'info', mac])
        devices.append((mac, name, 'Connected: yes' in info, 'Paired: yes' in info))
    return devices

def get_bt_powered():
    return 'Powered: yes' in run(['bluetoothctl', 'show'])

def device_icon(name):
    n = name.lower()
    if any(x in n for x in ['headphone', 'headset', 'earphone', 'airpod', 'buds']): return "󰋋"
    if 'keyboard' in n: return "󰌌"
    if 'mouse' in n: return "󰍽"
    if any(x in n for x in ['phone', 'iphone', 'android']): return "󰄜"
    if any(x in n for x in ['speaker', 'soundbar']): return "󰓃"
    if any(x in n for x in ['controller', 'gamepad']): return "󰊗"
    return "󰂯"


class BluetoothPopup(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("Bluetooth")
        self.set_default_size(320, -1)
        self.set_resizable(False)
        self.set_decorated(False)

        css = Gtk.CssProvider()
        css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        
        key = Gtk.EventControllerKey()
        key.connect('key-pressed', lambda c, k, *a: self.close() if k == Gdk.KEY_Escape else False)
        self.add_controller(key)

        self.build_ui()

    def build_ui(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(outer)

        hdr = Gtk.Label(label="󰂯  Bluetooth")
        hdr.add_css_class("header-label"); hdr.set_halign(Gtk.Align.START)
        outer.append(hdr)

        toggle_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        toggle_row.add_css_class("toggle-row")
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        info.set_hexpand(True)
        tl = Gtk.Label(label="Bluetooth"); tl.add_css_class("toggle-label"); tl.set_halign(Gtk.Align.START)
        ts = Gtk.Label(label="Pair and connect devices"); ts.add_css_class("toggle-sub"); ts.set_halign(Gtk.Align.START)
        info.append(tl); info.append(ts)
        toggle_row.append(info)
        self.bt_switch = Gtk.Switch()
        self.bt_switch.set_active(get_bt_powered())
        self.bt_switch.set_valign(Gtk.Align.CENTER)
        self.bt_switch.connect('notify::active', self.on_bt_toggle)
        toggle_row.append(self.bt_switch)
        outer.append(toggle_row)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_max_content_height(320)
        scroll.set_propagate_natural_height(True)
        self.dev_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        scroll.set_child(self.dev_box)
        outer.append(scroll)

        self.populate_devices()

        scan = Gtk.Button(label="󰑐  Scan for Devices")
        scan.add_css_class("btn-scan")
        scan.connect('clicked', self.on_scan)
        outer.append(scan)

    def populate_devices(self):
        while self.dev_box.get_first_child():
            self.dev_box.remove(self.dev_box.get_first_child())

        devices = get_bt_devices()
        connected = [(m, n) for m, n, c, p in devices if c]
        others = [(m, n) for m, n, c, p in devices if not c]

        if connected:
            lbl = Gtk.Label(label="CONNECTED"); lbl.add_css_class("section-label"); lbl.set_halign(Gtk.Align.START)
            self.dev_box.append(lbl)
            for mac, name in connected:
                self.dev_box.append(self.make_row(mac, name, True))

        if others:
            lbl2 = Gtk.Label(label="PAIRED DEVICES"); lbl2.add_css_class("section-label"); lbl2.set_halign(Gtk.Align.START)
            self.dev_box.append(lbl2)
            for mac, name in others[:10]:
                self.dev_box.append(self.make_row(mac, name, False))

        if not devices:
            no = Gtk.Label(label="No devices found. Try scanning.")
            no.add_css_class("no-devices"); no.set_halign(Gtk.Align.START)
            self.dev_box.append(no)

        return False

    def make_row(self, mac, name, connected):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row.add_css_class("device-row-connected" if connected else "device-row")
        icon = Gtk.Label(label=device_icon(name)); icon.add_css_class("device-icon")
        row.append(icon)
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        info.set_hexpand(True)
        n = Gtk.Label(label=name); n.add_css_class("device-name"); n.set_halign(Gtk.Align.START); n.set_ellipsize(3)
        info.append(n)
        s = Gtk.Label(label="Connected" if connected else mac)
        s.add_css_class("device-info-connected" if connected else "device-info"); s.set_halign(Gtk.Align.START)
        info.append(s); row.append(info)
        if connected:
            btn = Gtk.Button(label="Disconnect"); btn.add_css_class("btn-disconnect")
            btn.connect('clicked', lambda b, m=mac: (subprocess.Popen(['bluetoothctl', 'disconnect', m]), GLib.timeout_add(1200, self.populate_devices)))
        else:
            btn = Gtk.Button(label="Connect"); btn.add_css_class("btn-connect")
            btn.connect('clicked', lambda b, m=mac: (subprocess.Popen(['bluetoothctl', 'connect', m]), GLib.timeout_add(2000, self.populate_devices)))
        row.append(btn)
        return row

    def on_bt_toggle(self, switch, *args):
        subprocess.Popen(['bluetoothctl', 'power', 'on' if switch.get_active() else 'off'])
        GLib.timeout_add(600, self.populate_devices)

    def on_scan(self, btn):
        subprocess.Popen(['bash', '-c', 'bluetoothctl scan on & sleep 5; bluetoothctl scan off'])
        GLib.timeout_add(5500, self.populate_devices)


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='com.hypr.btpopup')
    def do_activate(self):
        BluetoothPopup(self).present()

App().run()

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Caelestia.Config
import Caelestia.Services

Scope {
    id: root

    enum PamState {
        None,
        Error,
        MaxTries,
        Failed
    }

    required property WlSessionLock lock

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    readonly property alias howdy: howdy

    property string lockMessage
    property int state
    property string buffer

    signal flashMsg

    function handleKey(event: KeyEvent): void {
        if (passwd.active)
            return;

        // Trigger howdy on enter while empty buffer
        if (howdy.canAttempt && !howdy.active && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && buffer.length === 0)
            return howdy.start(); // Gate on active so double enter still allows empty password

        if (state === Pam.MaxTries)
            return;

        // Abort howdy on pwd input
        if (howdy.active)
            howdy.abort();

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            console.log("[lock-debug] submit, buffer length:", buffer.length);
            passwd.start();
        } else if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier) {
                buffer = "";
            } else {
                buffer = buffer.slice(0, -1);
            }
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            // Allow anything except control characters
            buffer += event.text;
        }
    }

    function restartFprint(): void {
        fprint.reset();
        if (fprint.canAttempt)
            fprint.start();
        else
            fprint.abort();
    }

    function clearTransientState(): void {
        for (const obj of [root, fprint, howdy])
            if (obj.state !== Pam.MaxTries)
                obj.state = Pam.None;
    }

    // PIN verification (PAM-free): the bundled PAM stack errored on this
    // system for every attempt, and pam_unix rejected passwords that work in
    // `su`. So the lock checks a SHA-256 PIN hash instead. Nothing secret is
    // ever logged. Change the PIN by writing a new hash to the PIN file:
    //   printf 'NEWPIN' | sha256sum | cut -d' ' -f1 > ~/.config/caelestia/lockpin
    function sha256hex(ascii: string): string {
        function rightRotate(v: int, a: int): int {
            return (v >>> a) | (v << (32 - a));
        }
        var maxWord = Math.pow(2, 32);
        var result = "";
        var words = [];
        var asciiBitLength = ascii.length * 8;
        var h = [];
        var k = [];
        var primeCounter = 0;
        var isComposite = {};
        for (var candidate = 2; primeCounter < 64; candidate++) {
            if (!isComposite[candidate]) {
                for (var i = 0; i < 313; i += candidate) {
                    isComposite[i] = candidate;
                }
                h[primeCounter] = (Math.pow(candidate, 0.5) * maxWord) | 0;
                k[primeCounter++] = (Math.pow(candidate, 1 / 3) * maxWord) | 0;
            }
        }
        ascii += "\x80";
        while (ascii.length % 64 - 56) {
            ascii += "\x00";
        }
        for (var i = 0; i < ascii.length; i++) {
            var j = ascii.charCodeAt(i);
            if (j >> 8) {
                return "";
            }
            words[i >> 2] |= j << ((3 - i) % 4) * 8;
        }
        words[words.length] = (asciiBitLength / maxWord) | 0;
        words[words.length] = asciiBitLength;
        for (var j = 0; j < words.length;) {
            var w = words.slice(j, j += 16);
            var oldHash = h.slice();
            h = h.slice(0, 8);
            for (var i = 0; i < 64; i++) {
                var w15 = w[i - 15];
                var w2 = w[i - 2];
                var a = h[0];
                var e = h[4];
                var temp1 = h[7]
                    + (rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25))
                    + ((e & h[5]) ^ (~e & h[6]))
                    + k[i]
                    + (w[i] = i < 16 ? w[i] : (w[i - 16]
                        + (rightRotate(w15, 7) ^ rightRotate(w15, 18) ^ (w15 >>> 3))
                        + w[i - 7]
                        + (rightRotate(w2, 17) ^ rightRotate(w2, 19) ^ (w2 >>> 10))) | 0);
                var temp2 = (rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22))
                    + ((a & h[1]) ^ (a & h[2]) ^ (h[1] & h[2]));
                h = [(temp1 + temp2) | 0].concat(h);
                h[4] = (h[4] + temp1) | 0;
            }
            for (var i = 0; i < 8; i++) {
                h[i] = (h[i] + oldHash[i]) | 0;
            }
        }
        for (var i = 0; i < 8; i++) {
            for (var j = 3; j + 1; j--) {
                var b = (h[i] >> (j * 8)) & 255;
                result += ((b < 16 ? "0" : "") + b.toString(16));
            }
        }
        return result;
    }

    FileView {
        id: pinFile

        path: "/home/upicy/.config/caelestia/lockpin"
        watchChanges: true
    }

    QtObject {
        id: passwd

        property bool active: false
        property string message: ""

        function start(): void {
            if (active)
                return;
            active = true;
            console.log("[lock-debug] submit, buffer length:", root.buffer.length);
            if (!pinFile.loaded)
                console.log("[lock-debug] pin file not loaded, failing closed");
            var ok = pinFile.loaded && sha256hex(root.buffer) === pinFile.text().trim();
            root.buffer = "";
            active = false;
            root.clearTransientState();
            if (ok)
                return root.lock.unlock();
            root.state = Pam.Failed;
            root.flashMsg();
            pwdStateReset.restart();
        }

        function abort(): void {
            active = false;
        }
    }

    Timer {
        id: pwdStateReset

        interval: 4000
        onTriggered: {
            if (root.state !== Pam.MaxTries)
                root.state = Pam.None;
        }
    }

    ManualPamContext {
        id: fprint

        config: "fprint"
        availCommand: ["sh", "-c", "fprintd-list $USER"]
        retryOnFail: true
        enabled: GlobalConfig.lock.enableFprint
        maxTries: GlobalConfig.lock.maxFprintTries
        onAvailProcExited: root.restartFprint()
    }

    ManualPamContext {
        id: howdy

        config: "howdy"
        availCommand: ["sh", "-c", "command -v howdy"]
        enabled: GlobalConfig.lock.enableHowdy
        maxTries: GlobalConfig.lock.maxHowdyTries
    }

    Connections {
        function onResumed(): void {
            if (howdy.canAttempt && !howdy.active && GlobalConfig.lock.triggerHowdyOnWake)
                howdy.start();
        }

        target: SessionManager
    }

    Connections {
        function onSecureChanged(): void {
            if (root.lock.secure) {
                fprint.checkAvailable();
                howdy.checkAvailable();
                fprint.reset();
                howdy.reset();
                root.buffer = "";
                root.state = Pam.None;
                root.lockMessage = "";
            }
        }

        function onUnlock(): void {
            fprint.abort();
            howdy.abort();
            passwd.abort();
        }

        target: root.lock
    }

    Connections {
        function onEnableFprintChanged(): void {
            root.restartFprint();
        }

        function onEnableHowdyChanged(): void {
            if (!GlobalConfig.lock.enableHowdy && howdy.active)
                howdy.abort();
        }

        target: GlobalConfig.lock
    }

    component ManualPamContext: Scope {
        id: ctx

        required property bool enabled
        required property int maxTries
        property alias config: pam.config
        property alias availCommand: availProc.command
        property bool retryOnFail

        property bool available
        property int tries
        property int errorTries
        property int state
        readonly property bool canAttempt: available && enabled && root.lock.secure && tries < maxTries

        readonly property alias active: pam.active
        readonly property alias message: pam.message

        signal availProcExited(code: int)

        function checkAvailable(): void {
            availProc.running = true;
        }

        function start(): void {
            pam.start();
        }

        function abort(): void {
            pam.abort();
        }

        function reset(): void {
            tries = 0;
            errorTries = 0;
            state = Pam.None;
        }

        PamContext {
            id: pam

            configDirectory: Quickshell.shellPath("assets/pam.d")

            onCompleted: res => {
                if (!ctx.available)
                    return;

                if (res === PamResult.Success)
                    return root.lock.unlock();

                root.clearTransientState();

                if (res === PamResult.Error) {
                    ctx.state = Pam.Error;
                    ctx.errorTries++;
                    if (ctx.errorTries < 5) {
                        abort();
                        errorRetry.restart();
                    }
                } else if (res === PamResult.MaxTries || res === PamResult.Failed) {
                    ctx.tries++;
                    if (ctx.tries < ctx.maxTries) {
                        ctx.state = Pam.Failed;
                        if (ctx.retryOnFail)
                            start();
                    } else {
                        ctx.state = Pam.MaxTries;
                        abort();
                    }
                }

                root.flashMsg();
                stateReset.restart();
            }
        }

        Timer {
            id: errorRetry

            interval: 800
            onTriggered: pam.start()
        }

        Timer {
            id: stateReset

            interval: 4000
            onTriggered: {
                if (ctx.state !== Pam.MaxTries)
                    ctx.state = Pam.None;
                ctx.errorTries = 0;
            }
        }

        Process {
            id: availProc

            onExited: code => { // qmllint disable signal-handler-parameters
                ctx.available = code === 0;
                ctx.availProcExited(code);
            }
        }
    }
}

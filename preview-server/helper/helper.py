"""One-click login for the PR preview emulators.

POST /pr-<N>/api/login {"user": "tester1"} logs the app on android-pr-<N> in as that
test account, by driving its UI over adb (android-pr-<N>:5555 on the d0b0-preview
network), then clicks through the first-run prompts until the chat list shows.

Runs in its own container with no Docker socket: it can only reach the emulators'
adb ports and read testers.json. Caddy sends it /pr-*/api/*, which sits behind
Cloudflare Access. Only the Python standard library is used.
"""

import json
import re
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

APP_ID = "lv.d0b0.chat"
TESTERS = "/secrets/testers.json"
ROUTE = re.compile(r"^/pr-(\d+)/api/login$")
# First-run prompts after a fresh login, clicked in this order of preference.
# Never add "Reset account" here: it wipes the test account's encryption keys.
DISMISS = ["Do not show again", "Skip", "Continue", "Close"]

locks: dict[str, threading.Lock] = {}
locks_guard = threading.Lock()


class LoginError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


class Device:
    def __init__(self, pr):
        self.serial = f"android-pr-{pr}:5555"
        # The workflow recreates emulators under the same name, which leaves a stale
        # "offline" connection behind. Always start from a fresh one.
        run = lambda *a: subprocess.run(["adb", *a], capture_output=True, text=True, timeout=15).stdout
        run("disconnect", self.serial)
        run("connect", self.serial)
        if run("-s", self.serial, "get-state").strip() != "device":
            raise LoginError(404, f"No running emulator for PR #{pr}, or it is still booting.")

    def adb(self, *args):
        return subprocess.run(["adb", "-s", self.serial, *args], capture_output=True, text=True, timeout=30).stdout

    def nodes(self):
        self.adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
        nodes = []
        for n in re.findall(r"<node [^>]*>", self.adb("shell", "cat", "/sdcard/ui.xml")):
            attr = lambda k: (re.search(k + r'="([^"]*)"', n) or [None, ""])[1]
            x1, y1, x2, y2 = map(int, re.findall(r"\d+", attr("bounds")))
            nodes.append({
                "cls": attr("class"),
                "text": attr("text"),
                "desc": attr("content-desc"),
                "clickable": attr("clickable") == "true",
                "x": (x1 + x2) // 2,
                "y": (y1 + y2) // 2,
            })
        return nodes

    def tap(self, node):
        self.adb("shell", "input", "tap", str(node["x"]), str(node["y"]))

    def type(self, text):
        self.adb("shell", "input", "text", text)


def find(nodes, desc):
    return next((n for n in nodes if n["desc"] == desc), None)


def edit_fields(nodes):
    return [n for n in nodes if n["cls"].endswith("EditText")]


def login_fields(dev):
    # Right after a cold start the app can ignore the first tap on "Sign in",
    # so keep tapping it until the login form shows.
    for _ in range(20):
        nodes = dev.nodes()
        if len(fields := edit_fields(nodes)) >= 2:
            return fields
        if sign_in := find(nodes, "Sign in"):
            dev.tap(sign_in)
        time.sleep(1.5)
    raise LoginError(502, "The login screen did not appear.")


def on_chat_list(nodes):
    # The chat list also has a text field (search), so it is told apart by its buttons.
    return bool(find(nodes, "New chat") or find(nodes, "Search"))


def logged_in(nodes):
    # A new account gets "Set Up", one that logged in before gets "Restore".
    return on_chat_list(nodes) or any(find(nodes, d) for d in ("Set Up Crypto Identity", "Restore Crypto Identity"))


def login(pr, user):
    testers = json.load(open(TESTERS))
    account = next((a for a in testers["accounts"] if a["user"] == user), None)
    if account is None:
        raise LoginError(400, f"Unknown test account {user!r}.")
    mxid = f"@{account['user']}:{testers['homeserver']}"

    dev = Device(pr)
    dev.adb("shell", "monkey", "-p", APP_ID, "-c", "android.intent.category.LAUNCHER", "1")

    # A cold start (fresh install) takes a while before any screen is up, and the
    # first dumps can still show the previous app screen, so trust "logged in"
    # only when it is seen twice in a row.
    seen_chats = 0
    for _ in range(15):
        time.sleep(2)
        nodes = dev.nodes()
        seen_chats = seen_chats + 1 if on_chat_list(nodes) else 0
        if seen_chats >= 2:
            raise LoginError(409, "The app is already logged in. Log out in the app first.")
        if find(nodes, "Sign in") or len(edit_fields(nodes)) >= 2:
            break

    if not (find(nodes, "Sign in") or len(edit_fields(nodes)) >= 2):
        raise LoginError(409, "The app is not on its login screen. If it is already logged in, log out in the app first.")

    # The on-screen keyboard moves things around, so read the screen again before
    # each field, and clear whatever a previous attempt left in it (the app ignores
    # Ctrl+A, so: jump to the end and delete character by character).
    for i, value in enumerate([mxid, account["password"]]):
        dev.tap(login_fields(dev)[i])
        time.sleep(0.5)
        if leftover := len(login_fields(dev)[i]["text"]):
            dev.adb("shell", "input", "keyevent", "123", *["67"] * (leftover + 1))  # End, Delete...
        dev.type(value)
        time.sleep(0.5)
    dev.adb("shell", "input", "keyevent", "66")  # Enter submits the form

    # Logged in once the app shows the encryption setup or the chat list.
    for attempt in range(15):
        time.sleep(2)
        nodes = dev.nodes()
        if logged_in(nodes):
            break
        if attempt == 2 and (button := find(nodes, "Login")):
            dev.tap(button)  # Enter did not submit; use the button
    else:
        hint = next((n["desc"] for n in nodes if n["desc"] and not n["clickable"] and "Log in to" not in n["desc"]), "")
        raise LoginError(502, f"Login did not go through. {hint}".strip())

    for _ in range(10):
        if on_chat_list(nodes):
            return f"Logged in as {mxid}."
        prompt = next((n for d in DISMISS if (n := find(nodes, d)) and n["clickable"]), None)
        if prompt is None:
            time.sleep(2)
        else:
            dev.tap(prompt)
            time.sleep(2)
        nodes = dev.nodes()
    return f"Logged in as {mxid}. Some first-run prompts may still be open."


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        match = ROUTE.match(self.path)
        if not match:
            return self.reply(404, "Not found.")
        # A custom header can't be sent cross-site without a CORS preflight, which
        # this server never answers, so other sites can't trigger logins.
        if self.headers.get("X-D0b0-Preview") != "1":
            return self.reply(403, "Missing X-D0b0-Preview header.")
        pr = match.group(1)
        try:
            length = min(int(self.headers.get("Content-Length") or 0), 1024)
            user = json.loads(self.rfile.read(length) or b"{}").get("user", "")
        except (ValueError, AttributeError):
            return self.reply(400, "Body must be JSON like {\"user\": \"tester1\"}.")

        with locks_guard:
            lock = locks.setdefault(pr, threading.Lock())
        if not lock.acquire(blocking=False):
            return self.reply(409, "A login is already running on this emulator.")
        try:
            self.reply(200, login(pr, user))
        except LoginError as e:
            self.reply(e.status, str(e))
        except Exception as e:  # noqa: BLE001 - report anything else to the page
            self.reply(500, f"Login failed: {e}")
        finally:
            lock.release()

    def reply(self, status, message):
        body = json.dumps({"message": message}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    subprocess.run(["adb", "start-server"], capture_output=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

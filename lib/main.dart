import os
import json
import threading
from datetime import datetime

from kivy.app import App
from kivy.clock import Clock
from kivy.core.clipboard import Clipboard
from kivy.metrics import dp
from kivy.utils import get_color_from_hex
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.scrollview import ScrollView
from kivy.uix.popup import Popup

try:
    from google import genai
    from google.genai import types
except ImportError:
    genai = None
    types = None

APP_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(APP_DIR, "shadow_ai_history.json")
CONFIG_FILE = os.path.join(APP_DIR, "shadow_ai_config.json")
MODEL_NAME = "gemini-2.5-flash"

BG = get_color_from_hex("#0D0B14")
PANEL = get_color_from_hex("#191522")
PURPLE = get_color_from_hex("#9B7BFF")
TEXT = get_color_from_hex("#F6F2FF")
MUTED = get_color_from_hex("#B6ADC9")
USER_BG = get_color_from_hex("#302542")
ERROR = get_color_from_hex("#FF9A9A")

SYSTEM_PROMPT = (
    "أنت SHADOW AI، مساعد عربي مفيد ودقيق ومساعد برمجة. "
    "أجب بلغة المستخدم، اشرح الأكواد خطوة بخطوة، ونسّق الأكواد داخل علامات ``` "
    "ولا تخترع معلومات إذا لم تكن متأكدًا."
)

def load_json(path, fallback):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError, TypeError):
        return fallback

def save_json(path, data):
    temp = path + ".tmp"
    with open(temp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(temp, path)

class ShadowAIApp(App):
    title = "SHADOW AI"

    def build(self):
        self.history = load_json(HISTORY_FILE, [])
        self.config = load_json(CONFIG_FILE, {})
        self.busy = False
        self.client = None

        root = BoxLayout(orientation="vertical", padding=dp(10), spacing=dp(8))
        root.canvas.before.clear()
        with root.canvas.before:
            from kivy.graphics import Color, Rectangle
            Color(*BG)
            self.bg_rect = Rectangle(pos=root.pos, size=root.size)
        root.bind(pos=self._update_bg, size=self._update_bg)

        header = BoxLayout(size_hint_y=None, height=dp(58), spacing=dp(8))
        brand = Label(text="[b]SHADOW AI[/b]\\n[size=12]مساعدك الذكي والبرمجي[/size]",
                      markup=True, color=TEXT, halign="left", valign="middle")
        brand.bind(size=lambda w, s: setattr(w, "text_size", s))
        header.add_widget(brand)
        key_btn = Button(text="API KEY", size_hint_x=None, width=dp(92),
                         background_normal="", background_color=PURPLE, color=BG)
        key_btn.bind(on_release=lambda *_: self.show_key_popup())
        header.add_widget(key_btn)
        root.add_widget(header)

        toolbar = BoxLayout(size_hint_y=None, height=dp(42), spacing=dp(6))
        new_btn = Button(text="محادثة جديدة", background_normal="", background_color=PANEL)
        new_btn.bind(on_release=lambda *_: self.new_chat())
        copy_btn = Button(text="نسخ آخر رد", background_normal="", background_color=PANEL)
        copy_btn.bind(on_release=lambda *_: self.copy_last())
        toolbar.add_widget(new_btn)
        toolbar.add_widget(copy_btn)
        root.add_widget(toolbar)

        self.scroll = ScrollView(do_scroll_x=False)
        self.chat_box = BoxLayout(orientation="vertical", size_hint_y=None, spacing=dp(8), padding=dp(5))
        self.chat_box.bind(minimum_height=self.chat_box.setter("height"))
        self.scroll.add_widget(self.chat_box)
        root.add_widget(self.scroll, 1)

        self.status = Label(text="جاهز • أدخل مفتاح API من الزر بالأعلى", color=MUTED,
                            size_hint_y=None, height=dp(28), font_size="12sp")
        root.add_widget(self.status)

        composer = BoxLayout(size_hint_y=None, height=dp(100), spacing=dp(6))
        self.input = TextInput(hint_text="اكتب رسالتك هنا...", multiline=True,
                               background_color=PANEL, foreground_color=TEXT,
                               hint_text_color=MUTED, cursor_color=PURPLE,
                               padding=dp(10), size_hint_x=1)
        composer.add_widget(self.input)
        self.send_btn = Button(text="إرسال", size_hint_x=None, width=dp(76),
                               background_normal="", background_color=PURPLE, color=BG)
        self.send_btn.bind(on_release=lambda *_: self.send_message())
        composer.add_widget(self.send_btn)
        root.add_widget(composer)

        self.render_history()
        if not self.config.get("api_key"):
            Clock.schedule_once(lambda *_: self.show_key_popup(), 0.5)
        return root

    def _update_bg(self, widget, *_):
        self.bg_rect.pos = widget.pos
        self.bg_rect.size = widget.size

    def show_key_popup(self):
        box = BoxLayout(orientation="vertical", padding=dp(12), spacing=dp(10))
        box.add_widget(Label(
            text="ضع مفتاح Gemini API هنا. سيُحفظ محليًا على جهازك فقط.",
            color=TEXT, size_hint_y=None, height=dp(48)
        ))
        field = TextInput(text=self.config.get("api_key", ""), password=True,
                          multiline=False, hint_text="Gemini API key",
                          size_hint_y=None, height=dp(46))
        box.add_widget(field)
        row = BoxLayout(size_hint_y=None, height=dp(44), spacing=dp(8))
        save_btn = Button(text="حفظ", background_normal="", background_color=PURPLE, color=BG)
        cancel_btn = Button(text="إلغاء", background_normal="", background_color=PANEL)
        row.add_widget(save_btn)
        row.add_widget(cancel_btn)
        box.add_widget(row)
        popup = Popup(title="إعدادات SHADOW AI", content=box, size_hint=(0.92, None),
                      height=dp(240), separator_color=PURPLE)
        def save_key(*_):
            key = field.text.strip()
            if not key:
                self.status.text = "أدخل مفتاحًا صالحًا أولًا."
                return
            self.config["api_key"] = key
            save_json(CONFIG_FILE, self.config)
            self.client = None
            self.status.text = "تم حفظ المفتاح محليًا."
            popup.dismiss()
        save_btn.bind(on_release=save_key)
        cancel_btn.bind(on_release=lambda *_: popup.dismiss())
        popup.open()

    def render_history(self):
        self.chat_box.clear_widgets()
        if not self.history:
            self.add_bubble("assistant", "أهلًا بك في SHADOW AI ✦\\nاسألني عن البرمجة أو أي موضوع تريد فهمه.")
        else:
            for item in self.history[-80:]:
                self.add_bubble(item.get("role", "assistant"), item.get("content", ""))
        Clock.schedule_once(lambda *_: setattr(self.scroll, "scroll_y", 0), 0.1)

    def add_bubble(self, role, content):
        is_user = role == "user"
        box = BoxLayout(orientation="vertical", size_hint_y=None, padding=dp(11), spacing=dp(5))
        from kivy.graphics import Color, RoundedRectangle
        with box.canvas.before:
            Color(*(USER_BG if is_user else PANEL))
            rect = RoundedRectangle(pos=box.pos, size=box.size, radius=[dp(12)])
        box.bind(pos=lambda w, p: setattr(rect, "pos", p),
                 size=lambda w, s: setattr(rect, "size", s))
        title = Label(text="[b]أنت[/b]" if is_user else "[b]SHADOW AI[/b]",
                      markup=True, color=PURPLE if not is_user else TEXT,
                      size_hint_y=None, height=dp(22), halign="right", valign="middle")
        title.bind(size=lambda w, s: setattr(w, "text_size", s))
        body = Label(text=str(content), color=TEXT, size_hint_y=None,
                     halign="right", valign="top", markup=False)
        body.bind(width=lambda w, width: setattr(w, "text_size", (max(width-dp(8), dp(40)), None)))
        body.bind(texture_size=lambda w, size: setattr(w, "height", size[1] + dp(8)))
        box.add_widget(title)
        box.add_widget(body)
        box.height = dp(36) + body.height
        self.chat_box.add_widget(box)
        Clock.schedule_once(lambda *_: setattr(self.scroll, "scroll_y", 0), 0.1)

    def new_chat(self):
        self.history = []
        save_json(HISTORY_FILE, self.history)
        self.render_history()
        self.status.text = "بدأت محادثة جديدة."

    def copy_last(self):
        for item in reversed(self.history):
            if item.get("role") == "assistant":
                Clipboard.copy(item.get("content", ""))
                self.status.text = "تم نسخ آخر رد."
                return
        self.status.text = "لا يوجد رد لنسخه بعد."

    def send_message(self):
        prompt = self.input.text.strip()
        if not prompt or self.busy:
            return
        if not self.config.get("api_key"):
            self.show_key_popup()
            self.status.text = "أدخل مفتاح API أولًا."
            return
        if genai is None:
            self.status.text = "المكتبة غير مثبتة. نفّذ: pip install google-genai"
            return

        self.input.text = ""
        self.history.append({"role": "user", "content": prompt, "time": datetime.now().isoformat()})
        save_json(HISTORY_FILE, self.history)
        self.add_bubble("user", prompt)
        self.busy = True
        self.send_btn.disabled = True
        self.status.text = "SHADOW AI يفكر..."
        threading.Thread(target=self._request_worker, daemon=True).start()

    def _request_worker(self):
        try:
            if self.client is None:
                self.client = genai.Client(api_key=self.config["api_key"])
            contents = []
            for item in self.history[-20:]:
                role = item.get("role")
                content = item.get("content", "")
                if role == "user":
                    contents.append({"role": "user", "parts": [{"text": content}]})
                elif role == "assistant":
                    contents.append({"role": "model", "parts": [{"text": content}]})
            response = self.client.models.generate_content(
                model=MODEL_NAME,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    temperature=0.7,
                    max_output_tokens=2048
                )
            )
            answer = (response.text or "").strip()
            if not answer:
                answer = "لم يصل رد نصي. جرّب صياغة السؤال مرة أخرى."
            Clock.schedule_once(lambda *_: self._finish(answer, None), 0)
        except Exception as exc:
            # Avoid showing full exception strings that might contain request details.
            message = "تعذر الاتصال. تحقق من الإنترنت ومفتاح API وحصة الاستخدام."
            name = type(exc).__name__
            if "429" in str(exc) or "ResourceExhausted" in name:
                message = "وصلت إلى حد الاستخدام مؤقتًا. حاول لاحقًا."
            elif "401" in str(exc) or "403" in str(exc) or "PermissionDenied" in name:
                message = "المفتاح غير صالح أو لا يملك صلاحية الوصول."
            Clock.schedule_once(lambda *_: self._finish(None, message), 0)

    def _finish(self, answer, error):
        self.busy = False
        self.send_btn.disabled = False
        if error:
            self.status.text = error
            self.add_bubble("assistant", error)
            return
        self.history.append({"role": "assistant", "content": answer, "time": datetime.now().isoformat()})
        save_json(HISTORY_FILE, self.history)
        self.add_bubble("assistant", answer)
        self.status.text = "اكتمل الرد • محفوظ محليًا"

if __name__ == "__main__":
    ShadowAIApp().run()

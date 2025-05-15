import tkinter as tk
from tkinter.scrolledtext import ScrolledText
from subprocess import Popen, PIPE
import os
import re


# Script dizini (gerekiyorsa tam yol ver)
SCRIPT_DIR = "/home/grass/.local/bin"  # örneğin: "/home/user/scripts"
MAX_DISPLAY_CHARS = 10000

SCRIPTS = [
    "start_air.sh",
    "stop_air.sh",
    "start_control.sh",
    "start_camera.sh",
    "start_nav2.sh",
    "start_dock.sh",
    "start_undock.sh"
]

# Emoji → metin eşlemeleri
EMOJI_MAP = {
    "✅": "[OK]",
    "🛑": "[STOP]",
    "🚀": "[START]",
    "🔍": "[CHECK]",
    "ℹ️": "[INFO]",  # emoji versiyonu
    "ℹ": "[INFO]",   # metin versiyonu
    "❌": "[FAIL]",
    "⚠️": "[WARN]",
    "🔧": "[SETUP]",
    "📦": "[DOCKER]",
    "📡": "[NETWORK]",
    "📁": "[FILE]",
    "🧠": "[AI]",
    "🕒": "[WAIT]",
    "🔄": "[RETRY]",
    "🧹": "[CLEAN]",
    "📶": "[WIFI]",
}

def is_emoji(char):
    return bool(re.match(r"[\U0001F600-\U0001F64F"
                         r"\U0001F300-\U0001F5FF"
                         r"\U0001F680-\U0001F6FF"
                         r"\U0001F1E0-\U0001F1FF"
                         r"\u2600-\u26FF"
                         r"\u2700-\u27BF"
                         r"\uFE0F]", char))

def replace_emojis(text):
    # Önce haritada tanımlı emojileri değiştir
    for emoji_char, replacement in EMOJI_MAP.items():
        text = text.replace(emoji_char, replacement)
    
    # Geriye kalan ama eşleşmemiş emojiler varsa, onları da genel [EMOJI] ile değiştir
    return ''.join(
        '[EMOJI]' if is_emoji(c) else c
        for c in text
    )

def append_safe(text):
    try:
        filtered = replace_emojis(text)
        current = output_text.get("1.0", tk.END)
        combined = current + filtered
        if len(combined) > MAX_DISPLAY_CHARS:
            combined = combined[-MAX_DISPLAY_CHARS:]
        output_text.delete("1.0", tk.END)
        output_text.insert(tk.END, combined)
        output_text.see(tk.END)
        root.update_idletasks()
    except Exception as e:
        print(f"[GUI yazım hatası]: {e}")

def run_script(script_name):
    script_path = os.path.join(SCRIPT_DIR, script_name)
    try:
        output_text.delete("1.0", tk.END)
        append_safe(f"[{script_name}] çalıştırılıyor...\n\n")
        process = Popen(["bash", script_path], stdout=PIPE, stderr=PIPE, text=True, bufsize=1)

        def read_output():
            try:
                for line in process.stdout:
                    append_safe(line)
                for line in process.stderr:
                    append_safe("[HATA] " + line)
                process.wait()
                append_safe(f"\n[{script_name}] tamamlandı.\n")
            except Exception as e:
                append_safe(f"\n⚠️ HATA (okuma): {e}")

        root.after(100, read_output)

    except Exception as e:
        append_safe(f"\n⚠️ HATA (başlatma): {e}")

# GUI kurulum
root = tk.Tk()
root.title("Script Starter")
root.geometry("800x600")

frame = tk.Frame(root)
frame.pack(pady=10)

for script in SCRIPTS:
    btn = tk.Button(frame, text=script, width=25, command=lambda s=script: run_script(s))
    btn.pack(pady=2)

output_text = ScrolledText(root, wrap=tk.WORD, height=30)
output_text.pack(padx=10, pady=10, fill=tk.BOTH, expand=True)

COW_SAY = r"""
 ____________________________
< ROS Script Runner Açıldı! >
 ----------------------------
        \   ^__^
         \  (oo)\_______             
            (__)\       )\/\
                ||----w |
                ||     ||
"""

output_text.insert(tk.END, COW_SAY)
output_text.insert(tk.END, "\nKomutlardan birini seçerek çalıştırabilirsiniz.\n\n")
output_text.insert(tk.END, "Don't forget to join air WIFI network.\n\n")
output_text.see(tk.END)

root.mainloop()
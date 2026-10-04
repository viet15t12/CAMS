import sys
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QUrl

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
# We can't easily run it, but we can look for "TypeError: Cannot read property 'trim' of undefined" in standard output if we could run it.

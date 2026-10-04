import sys
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
engine.load("/data/Projects/CAMS_2/UI/qml/app/Main.qml")
if not engine.rootObjects():
    sys.exit(-1)

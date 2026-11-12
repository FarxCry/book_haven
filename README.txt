PURANA lib FOLDER DELETE KARKE IS ZIP KA lib COPY KARO, PHIR:

$env:Path = "C:\src\flutter\bin;C:\Program Files\Git\cmd;" + $env:Path
cd C:\bookstore_app
flutter clean
flutter pub get
flutter run -d chrome --web-port 8080

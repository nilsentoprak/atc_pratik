# ATC Telsiz Konuşma Pratiği

Pilot adayları için Flutter/Dart ile geliştirilmiş sesli ATC (hava trafik kontrol) telsiz konuşma eğitim uygulaması.

## Özellikler

- Kule talimatları metin-ses dönüşümü (flutter_tts) ile sesli oynatılır
- Mikrofon düğmesine basılarak söylenen geri okuma, konuşma tanıma (speech_to_text) ile metne çevrilir
- Sayı ve fonetik ifadeler ("niner", "tree") normalleştirilerek kelime bazlı puanlanır
- 5 uçuş evresi: taksi, kalkış, transponder, tırmanış, iniş
- Evre bazlı sonuç özeti ve tekrar deneme

## Kurulum

    flutter pub get
    flutter run

## Kullanılan Teknolojiler

Flutter, Dart, flutter_tts, speech_to_text

## Sınırlılıklar

Eğitim amaçlı bir prototiptir, resmî uçuş eğitiminin yerini tutmaz.

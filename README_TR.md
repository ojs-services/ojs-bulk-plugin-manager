# OJS Eklenti Yönetiminde Devrim: Bulk Plugin Manager

**OJS 3.3.x için geliştirilen bu ücretsiz eklenti, eklenti yönetimini kolaylaştırıyor, yaygın sorunları çözüyor ve size saatler kazandırıyor.**

---

## 🎯 Neden Bu Eklentiyi Geliştirdik?

OJS kullanıcılarının en sık karşılaştığı sorunlardan biri: **"Eklentiler sayfası açılmıyor!"**

Bu sorun genellikle veritabanı ile dosya sistemindeki versiyon uyumsuzluğundan kaynaklanır. OJS'nin standart arayüzü bu durumda tamamen kilitleniyor ve yöneticiler çaresiz kalıyor.

İşte tam da bu sorunu çözmek için **Bulk Plugin Manager**'ı geliştirdik.

---

## ✨ Öne Çıkan Özellikler

### 📊 Anlık Dashboard
Tek bakışta tüm eklenti durumunuzu görün:
- OJS versiyonunuz
- Kurulu, aktif ve pasif eklenti sayıları
- Güncelleme bekleyen eklentiler
- Sorunlu eklentiler

### 🔧 Otomatik Sorun Tespiti
Eklenti, aşağıdaki sorunları otomatik olarak tespit eder:
- **Senkronizasyon sorunları:** Veritabanı ve dosya versiyonu farklı
- **Eksik dosyalar:** Veritabanında kayıt var ama dosyalar silinmiş
- **Versiyon çakışmaları:** Yerel versiyon Gallery versiyonundan yüksek

### ⚡ Tek Tıkla Düzeltme
Her sorun için hazır çözüm butonları:
- **DB Düzelt:** Veritabanı versiyonunu dosya ile eşitler
- **DB Temizle:** Sahipsiz kayıtları temizler
- **Yükle:** Eksik dosyaları Gallery'den indirir
- **Güncelle:** Eklentiyi son sürüme günceller

### 🌍 Çoklu Dil Desteği
- 🇬🇧 English
- 🇹🇷 Türkçe

### 📱 Modern Arayüz
- Responsive tasarım
- Akıllı filtreleme sistemi
- Toplu işlem desteği
- Gerçek zamanlı ilerleme göstergesi

---

## 🚀 Ne Zaman Kullanmalısınız?

### 1. OJS Eklenti Sayfası Açılmıyorsa
En yaygın senaryo! Veritabanı-dosya uyumsuzluğu nedeniyle OJS eklenti sayfası kilitlendiğinde, Bulk Plugin Manager kurtarıcınız olur. URL ile doğrudan erişebilirsiniz:
```
https://siteniz.com/index.php/dergi/bulkPluginManager
```

### 2. Çok Sayıda Eklenti Güncelleyecekseniz
Standart OJS arayüzünde eklentileri tek tek güncellemek zorunda kalırsınız. Bulk Plugin Manager ile birden fazla eklentiyi seçip tek tıkla güncelleyebilirsiniz.

### 3. Eklenti Temizliği Yapacaksanız
Silinen eklentilerin veritabanında kalan "hayalet" kayıtlarını tespit edip temizlemek için idealdir.

### 4. Hızlı Durum Kontrolü İçin
Dashboard kartları ile anlık özet alabilir, sorunları hemen fark edebilirsiniz.

---

## 📑 Tab'lar Ne Anlama Geliyor?

| Tab | Açıklama |
|-----|----------|
| 🔌 **Kurulu** | Tüm kurulu eklentiler. DB ve dosya versiyonlarını yan yana gösterir. |
| 🔧 **DB Düzeltme Gerekli** | Veritabanı versiyonu Gallery'den yüksek olanlar. Düzeltme gerektirir. |
| 🔄 **Senkron Sorunu** | DB ve dosya versiyonu farklı olanlar. OJS sayfasının kilitlenmesine neden olabilir. |
| 📁 **Eksik Dosya** | Dosyası silinmiş ama DB kaydı duran eklentiler. |
| ⬆️ **Güncellemeler** | Güncelleme bekleyen eklentiler. |
| 📦 **Yüklenebilir** | Henüz kurulmamış, yüklenebilir eklentiler. |
| ⚠️ **Yüklü Daha Yeni** | Yerel versiyon Gallery'den yeni. Genellikle sorun değil. |
| ❓ **Gallery'de Yok** | PKP Gallery'de olmayan özel eklentiler. |
| ℹ️ **Bilgi** | Kapsamlı kullanım kılavuzu. |

---

## 🔍 Filtreler Nasıl Çalışıyor?

**Kurulu** tab'ında 5 filtre bulunur:

| Filtre | Gösterdiği |
|--------|------------|
| **Tümü** | Tüm eklentiler |
| **Aktif** | Sadece aktif olanlar |
| **Pasif** | Sadece pasif olanlar |
| **Senkron Sorunu** | DB ≠ Dosya versiyonu olanlar |
| **Eksik Dosya** | Dosyası olmayan eklentiler |

---

## 🛠️ Butonlar Ne Yapar?

### 🔧 DB Düzelt (Fix DB)
Veritabanı versiyonunu dosya versiyonuyla eşitler. Şu durumlarda kullanın:
- OJS eklenti sayfası açılmıyorsa
- Eklenti "current=0" hatasında kalmışsa
- Manuel müdahale sonrası versiyon uyuşmazlığı varsa

### 🗑️ DB Temizle (Clean DB)
Eklentinin tüm veritabanı kayıtlarını siler (versions + plugin_settings). Şu durumlarda kullanın:
- Eklenti dosyalarını manuel sildiyseniz
- Eklenti listede görünüyor ama dosyası yoksa

### 📦 Yükle (Install)
Eklentiyi PKP Gallery'den indirir ve kurar. Şu durumlarda kullanın:
- Yeni eklenti kuracaksanız
- Eksik dosyaları yeniden indirmek istiyorsanız

### ⬆️ Güncelle (Update)
Gallery'den son sürümü indirir ve günceller.

---

## 🐛 Sık Karşılaşılan Sorunlar ve Çözümleri

### Sorun 1: OJS Eklenti Sayfası Açılmıyor
**Sebep:** Veritabanı versiyonu dosya versiyonuyla eşleşmiyor. OJS bu durumda current=0 yapıyor ve sayfa kilitleniyor.

**Çözüm:** 
1. Bulk Plugin Manager'a URL ile erişin
2. "Kurulu" tab'ına gidin
3. "Senkron Sorunu" filtresini seçin
4. Her satırda "DB Düzelt" butonuna tıklayın

### Sorun 2: Silinen Eklenti Hala Listede
**Sebep:** Dosyalar silindi ama veritabanı kayıtları duruyor.

**Çözüm:**
1. "Kurulu" tab'ına gidin
2. "Eksik Dosya" filtresini seçin
3. "DB Temizle" butonuna tıklayın

### Sorun 3: Eklenti Güncellenmiyor
**Sebep:** Yerel versiyon Gallery versiyonundan yüksek (downgrade koruması).

**Çözüm:**
1. "DB Düzeltme Gerekli" tab'ına gidin
2. "DB Düzelt" ile versiyonu sıfırlayın
3. Ardından normal güncelleme yapın

---

## ⚙️ Teknik Detaylar

- **Uyumluluk:** OJS 3.3.x (3.3.0.0 - 3.3.0.21)
- **OJS 3.4+ Koruması:** Uyumsuz versiyonda otomatik olarak devre dışı kalır
- **Versiyon Karşılaştırma:** 4 parçaya normalize edilir (1.0.0 → 1.0.0.0)
- **Case-Insensitive:** openAIRE = openaire olarak değerlendirilir
- **Gallery Kaynağı:** pkp.sfu.ca/ojs/xml/plugins.xml

---

## 📥 Kurulum

1. Eklenti dosyasını indirin
2. `/plugins/generic/` klasörüne çıkartın
3. OJS Admin Panel > Website Settings > Plugins
4. Generic Plugins > "Bulk Plugin Manager for OJS" → Enable
5. Sol menüde "🔌 Bulk Plugin Manager" linkine tıklayın

**Alternatif Erişim:**
```
https://siteniz.com/index.php/DERGI/bulkPluginManager
```

---

## 📥 İndirme Linkleri

<!-- İNDİRME LİNKLERİ BURAYA EKLENECEK -->



---

## 📌 Önemli Notlar

⚠️ **Yedek Alın:** Veritabanı işlemleri yapmadan önce yedek almanız önerilir.

👤 **Yetki:** Sadece Site Administrator ve Journal Manager rolleri erişebilir.

🔒 **OJS 3.4+ Güvenliği:** Bu eklenti sadece OJS 3.3.x ile uyumludur. OJS 3.4 veya üstüne yüklenirse otomatik olarak devre dışı kalır, beyaz ekran veya hata oluşmaz.

🌐 **İnternet:** Eklenti bilgileri PKP Gallery'den çekilir, internet bağlantısı gereklidir.

---

## 📊 Versiyon Geçmişi

| Versiyon | Özellikler |
|----------|------------|
| 1.5.3 | OJS 3.4+ koruma, sol menü entegrasyonu, Info sayfası |
| 1.4.x | Missing Files filtresi, performans iyileştirmeleri |
| 1.3.x | Modern UI, Dashboard, case-insensitive karşılaştırma |
| 1.0.0 | İlk sürüm |

---

## 🤝 Destek

Sorularınız veya önerileriniz için:
- GitHub Issues
- OJS Community Forum
- support@ojsservices.com

---

## 📄 Lisans

Bu eklenti **GNU General Public License v3** altında ücretsiz olarak sunulmaktadır.

---

*OJS Services tarafından ❤️ ile geliştirilmiştir.*

# Bulk Plugin Manager for OJS

**Version:** 1.6.0  
**Compatibility:** OJS 3.3.x only (3.3.0.0 - 3.3.0.21)  
**Author:** OJS Services  
**License:** GPL v3

---

## 📋 Açıklama

Bulk Plugin Manager, Open Journal Systems (OJS) için geliştirilmiş kapsamlı bir eklenti yönetim aracıdır. OJS'nin standart eklenti galerisi arayüzünün aksine, tüm eklentileri tek bir sayfada görüntüler, toplu işlemler yapmanıza olanak tanır ve veritabanı-dosya senkronizasyon sorunlarını tespit edip düzeltir.

---

## 🎯 Ne Zaman Kullanılmalı?

### 1. OJS Eklenti Sayfası Kilitlendiğinde
OJS'nin `/management/settings/website` > `Plugins` sayfası bazen yüklenmiyor veya çok yavaş açılıyorsa, bu genellikle veritabanı-dosya versiyon uyumsuzluğundan kaynaklanır. Bulk Plugin Manager bu sorunu tespit edip düzeltir.

### 2. Çok Sayıda Eklenti Güncellemesi Gerektiğinde
Standart OJS arayüzünde eklentileri tek tek güncellemek zorunda kalırsınız. Bu eklenti ile birden fazla eklentiyi seçip toplu güncelleme yapabilirsiniz.

### 3. Eklenti Durumunu Hızlıca Görmek İstediğinizde
Dashboard kartları ile anlık özet:
- Kaç eklenti kurulu?
- Kaç tanesi aktif/pasif?
- Kaç tanesi güncellenebilir?
- Sorunlu eklentiler var mı?

### 4. Veritabanı Temizliği Gerektiğinde
Silinen eklentilerin veritabanında kalan "hayalet" kayıtlarını tespit edip temizleyebilirsiniz.

### 5. Versiyon Uyumsuzluklarını Düzeltmek İçin
Elle yapılan müdahaleler veya hatalı güncellemeler sonucu oluşan DB-dosya versiyon farklılıklarını tek tıkla düzeltebilirsiniz.

---

## ✨ Özellikler

### 🖥️ Modern Dashboard
- **OJS Versiyonu:** Sistemin çalıştığı OJS sürümü
- **Gallery Eklentileri:** PKP Gallery'deki uyumlu eklenti sayısı
- **Kurulu:** Sistemde kayıtlı toplam eklenti
- **Aktif/Pasif:** Etkin ve devre dışı eklenti sayıları
- **DB Fix:** Veritabanı düzeltmesi gereken eklentiler
- **Yüklenebilir:** Henüz kurulmamış uyumlu eklentiler
- **Yüklü Daha Yeni:** Yerel versiyonu Gallery'den yeni olan eklentiler

### 📑 Akıllı Tab Sistemi

| Tab | Açıklama |
|-----|----------|
| **Installed** | Tüm kurulu eklentiler (DB ve Dosya versiyonları yan yana) |
| **DB Fix Required** | Veritabanı versiyonu Gallery'den yüksek olanlar |
| **Available** | Kurulabilecek yeni eklentiler |
| **Newer Installed** | Yerel versiyon > Gallery versiyonu |
| **Not in Gallery** | Gallery'de olmayan özel eklentiler |

### 🔍 Gelişmiş Filtreleme (Installed Tab)
- **All:** Tüm eklentiler
- **Active:** Sadece aktif olanlar
- **Inactive:** Sadece pasif olanlar
- **Sync Issues:** DB ≠ Dosya versiyonu olanlar
- **Missing Files:** Dosyası silinmiş ama DB'de kaydı duranlar

### 🛠️ Düzeltme Araçları

| Buton | İşlev |
|-------|-------|
| **🔧 Fix DB** | Veritabanı versiyonunu dosya versiyonuyla eşitler |
| **📦 Install** | Eksik dosyaları Gallery'den indirir |
| **🗑️ Clean DB** | Dosyası olmayan eklentinin DB kayıtlarını siler |
| **⬆️ Update** | Eklentiyi Gallery'deki son sürüme günceller |

### 🌍 Çoklu Dil Desteği
- 🇬🇧 English
- 🇹🇷 Türkçe

Sağ üst köşedeki EN/TR butonlarıyla anında dil değiştirebilirsiniz.

---

## 🔧 Teknik Detaylar

### Veritabanı Sorgu Mantığı
Eklenti, OJS'nin `versions` tablosunu sorgularken akıllı bir mantık kullanır:

```
1. current=1 olan kayıt varsa → onu kullan
2. current=1 yoksa → en yüksek versiyonu al
```

Bu sayede OJS'nin otomatik olarak `current=0` yaptığı "bozuk" eklentiler de görünür ve düzeltilebilir.

### Case-Insensitive Karşılaştırma
Veritabanında `openAIRE`, dosya sisteminde `openaire` gibi farklılıklar sorun çıkarmaz. Tüm karşılaştırmalar case-insensitive yapılır.

### Versiyon Normalizasyonu
`1.0.0` ve `1.0.0.0` aynı kabul edilir. Tüm versiyonlar 4 parçaya normalize edilir.

### Güvenli SQL İşlemleri
- SELECT için `retrieve()`
- UPDATE/DELETE/INSERT için `update()`
- Tüm sorgular parameterized (SQL injection koruması)

---

## 📥 Kurulum

1. Eklenti dosyasını indirin
2. `/plugins/generic/` klasörüne çıkartın
3. OJS Admin Panel > Website Settings > Plugins
4. Generic Plugins > "Bulk Plugin Manager for OJS" → Enable
5. Araç çubuğunda "Bulk Plugin Manager" linkine tıklayın

**Alternatif Erişim:**
```
https://yourjournal.com/index.php/JOURNAL_PATH/bulkPluginManager
```

---

## 🐛 Çözdüğü Yaygın Sorunlar

### 1. "OJS Eklenti Sayfası Açılmıyor"
**Sebep:** Veritabanındaki versiyon ile dosyadaki versiyon uyuşmuyor. OJS bu durumda sayfayı yükleyemiyor.

**Çözüm:** Bulk Plugin Manager > Installed tab > "Sync Issues" filtresi > Fix DB

### 2. "Eklenti Silindi Ama Hala Listede"
**Sebep:** Dosyalar silindi ama `versions` ve `plugin_settings` tablolarında kayıtlar duruyor.

**Çözüm:** Bulk Plugin Manager > Installed tab > "Missing Files" filtresi > Clean DB

### 3. "Eklenti Güncellenmiyor"
**Sebep:** DB versiyonu Gallery versiyonundan yüksek (downgrade koruması).

**Çözüm:** Bulk Plugin Manager > DB Fix Required tab > Fix DB (önce versiyonu düzelt, sonra güncelle)

### 4. "current=0 Sorunu"
**Sebep:** OJS, dosyadaki version.xml ile DB'deki versiyonu karşılaştırır. Eşleşmezse `current=0` yapar.

**Çözüm:** Fix DB butonu ile DB versiyonunu dosya versiyonuyla eşitle.

---

## 📊 Versiyon Geçmişi

| Versiyon | Tarih | Değişiklikler |
|----------|-------|---------------|
| 1.5.3 | 2024-12 | OJS 3.4+ koruma eklendi (uyumsuz versiyonda sessizce devre dışı kalır) |
| 1.6.0 | 2024-12 | Tüm tablar her zaman görünür (boş olanlar da), yeşil 0 badge, boş tab açıklamaları |
| 1.5.3 | 2024-12 | OJS 3.4+ koruma eklendi (uyumsuz versiyonda sessizce devre dışı) |
| 1.5.2 | 2024-12 | Sol menü tüm admin sayfalarında görünür (Statistics dahil) |
| 1.5.1 | 2024-12 | Sol menüde link eklendi (admin panelinde her sayfada görünür) |
| 1.5.0 | 2024-12 | Kapsamlı Bilgi/Info tab'ı eklendi (kullanım kılavuzu) |
| 1.4.1 | 2024-12 | İşlem sonrası otomatik yenileme kaldırıldı (daha hızlı toplu işlem) |
| 1.4.0 | 2024-12 | Missing Files filtresi eklendi |
| 1.3.9 | 2024-12 | Sorgu mantığı düzeltildi (current=1 önceliği) |
| 1.3.8 | 2024-12 | DB Fix fonksiyonu güçlendirildi |
| 1.3.7 | 2024-12 | current=0 kayıtları artık görünür |
| 1.3.6 | 2024-12 | Performans iyileştirmesi, Clean DB düzeltmesi |
| 1.3.5 | 2024-12 | Missing dosyalar için Install/Clean DB butonları |
| 1.3.4 | 2024-12 | Installed tab'a DB/File sütunları eklendi |
| 1.3.3 | 2024-12 | Case-insensitive karşılaştırma |
| 1.3.0 | 2024-12 | Modern UI, Dashboard, Tab sistemi |
| 1.0.0 | 2024-11 | İlk sürüm |

---

## ⚠️ Önemli Notlar

1. **Yedek Alın:** Veritabanı işlemleri yapmadan önce yedek almanız önerilir.

2. **Admin Yetkisi:** Bu eklenti sadece Site Administrator ve Journal Manager rollerine açıktır.

3. **OJS 3.3 Uyumluluğu:** Bu eklenti **sadece OJS 3.3.x** serisi için geliştirilmiştir (3.3.0.0 - 3.3.0.21).
   - ✅ OJS 3.4+ sistemlere yüklenirse **otomatik olarak devre dışı kalır**
   - ✅ Beyaz ekran veya hata oluşmaz
   - ✅ Hata logu kaydedilir: `Bulk Plugin Manager: Bu eklenti sadece OJS 3.3.x ile uyumludur`

4. **Gallery Bağımlılığı:** Eklenti bilgileri PKP Plugin Gallery'den (`pkp.sfu.ca/ojs/xml/plugins.xml`) çekilir. İnternet bağlantısı gereklidir.

---

## 🤝 Destek

Sorularınız veya önerileriniz için:
- GitHub Issues
- OJS Community Forum
- support@ojsservices.com

---

## 📄 Lisans

Bu eklenti GNU General Public License v3 altında lisanslanmıştır.

```
Copyright (C) 2024 OJS Services

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

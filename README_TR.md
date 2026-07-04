# OJS Toplu Eklenti Yöneticisi

![Version](https://img.shields.io/badge/versiyon-1.11.0-blue)
![OJS](https://img.shields.io/badge/OJS-3.3.x-green)
![License](https://img.shields.io/badge/lisans-GPL--3.0-orange)

Open Journal Systems (OJS) 3.3.x için kapsamlı eklenti yönetim paneli. Tüm eklentilerinizi tek sayfadan yönetin, güncelleyin, kurun ve sorunları giderin.

![Ekran Görüntüsü](screenshot1.png)

## Özellikler

- **Dashboard** - Tüm eklentilerin durum özetini tek bakışta görün
- **Toplu İşlem** - Birden fazla eklentiyi seçip tek seferde güncelleyin/kurun
- **OJS Services** - [github.com/ojs-services](https://github.com/ojs-services) eklentilerini doğrudan kurun
- **DB Senkronizasyon** - OJS eklenti sayfasını çökerten veritabanı-dosya uyumsuzluklarını tespit edip onarın
- **Yedekleme & Geri Yükleme** - Güncelleme sırasında otomatik yedek, tek tıkla geri yükleme
- **PKP Gallery** - Resmi PKP Eklenti Galerisi'nden uyumlu eklentileri kurun
- **Kenar Menüsü** - OJS tarzı sol menü ile hızlı navigasyon
- **Çift Dil** - Türkçe ve İngilizce arayüz

## Kurulum

1. [Releases](../../releases) sayfasından `bulkPluginManager.tar.gz` dosyasını indirin
2. OJS kurulumunuzdaki `plugins/generic/` klasörüne çıkartın
3. Web Sitesi Ayarları > Eklentiler > Genel Eklentiler altından **Bulk Plugin Manager**'ı etkinleştirin

## Erişim

```
https://siteniz.com/index.php/DERGI/bulkPluginManager
```

Veya OJS kenar menüsündeki **Bulk Plugin Manager** bağlantısına tıklayın.

## Uyumluluk

OJS 3.3.0.0 - 3.3.0.22

## Güvenlik

Durum değiştiren tüm işlemler geçerli bir OJS CSRF token'ı gerektirir. Eklentiyi
hem **site yöneticileri** hem de **dergi yöneticileri** kullanabilir — editörlerin
site admin hesabı olmadan eklenti yönetebilmesi bu eklentinin temel amacıdır.
(Eklenti etkinleştirme dergiye özeldir; dergi yöneticisinin kurduğu bir eklenti
başka dergilerde otomatik aktifleşmez.) Eklenti paketleri yalnızca güvenilir PKP
Gallery / `ojs-services` GitHub adreslerinden HTTPS üzerinden indirilir ve her
arşiv, çıkarımdan önce dizin-aşımı ("Zip Slip") girdilerine karşı denetlenir.
Uzak kaynaklardan gelen XML, ağ erişimi ve dış varlıklar kapalı şekilde
(XXE-güvenli) ayrıştırılır.

> **Not:** GitHub release indirmeleri HTTPS ve katı host beyaz-listesi ile
> korunur. Release dosyaları checksum yayınlamadığından `ojs-services`
> indirmeleri için ek hash doğrulaması yapılmaz.

## İsteğe Bağlı Yapılandırma

Eklenti, `ojs-services` eklentilerini GitHub API üzerinden keşfeder; bu API
anonim çağrılar için saatte 60 istekle sınırlıdır. Bunu saatte 5000'e çıkarmak
için `config.inc.php` dosyasına bir kişisel erişim token'ı ekleyin:

```ini
[bulk_plugin_manager]
github_token = "ghp_your_token_here"
```

Token'ın herhangi bir yetkiye ihtiyacı yoktur (yalnızca genel depolar). Ayar yoksa
anonim erişim kullanılır ve limite ulaşılırsa önbellekteki depo listesi gösterilir.

## Lisans

[GPL v3](LICENSE)

## Geliştirici

[OJS Services](https://github.com/ojs-services)

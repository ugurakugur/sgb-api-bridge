# SGB → Tehdit İstihbaratı Platformu / SIEM Entegrasyonları

SGB indicator feed'inizi tüketmek isteyen sistemler için adım-adım kurulum
rehberleri. Hepsi tek bir public TAXII 2.1 endpoint üzerinden çalışır —
ürünün built-in TAXII client'ı yeter, özel script veya artifact build'i
yoktur. Tümü Türkçe, **Bilgi ve İletişim Güvenliği Rehberi** maddeleri
ile eşleştirilmiştir.

## Tek endpoint, tüm ürünler

```
Discovery: https://sgb-taxii.bilsec.tr/taxii2/
API root:  https://sgb-taxii.bilsec.tr/api/
Auth:      yok (anonim)
```

8 koleksiyon, [use case kütüphanesi](../usecases/) ile birebir eşleşir:

| Koleksiyon | İçerik (connectiontype) | UC prefix |
|---|---|---|
| `sgb-phishing` | Phishing (PH) | UC-PH-* |
| `sgb-botnet-cc` | Botnet C&C (BC) | UC-BC-* |
| `sgb-apt-cc` | APT C&C (AC) | UC-AC-* |
| `sgb-exploit-kit` | Exploit Kit (EK) | UC-EK-* |
| `sgb-malware-download` | Malware Download (MF) | UC-MF-* |
| `sgb-mining` | Cryptomining (MM) | UC-MM-* |
| `sgb-mobile-cc` | Mobile C&C (MC) | UC-MC-* |
| `sgb-other` | Diğer (OT) | UC-OT-* |

Detaylı koleksiyon dokümanı: [../setup-taxii.md](../setup-taxii.md)

## BG Rehberi karşılığı (özet)

| Entegrasyon | Doğrudan karşıladığı BG maddeleri |
|-------------|------------------------------------|
| QRadar, Splunk, Sentinel | **3.1.8.6** (Merkezi Kayıt Yönetimi), **3.1.8.7** (Kayıt Analizi Araçları/SIEM), **3.1.8.8** (SIEM düzenli yapılandırma), **3.1.10.4** (Siber Tehdit Bildirimlerinin Yönetilmesi) |
| MISP, OpenCTI | **3.1.10.4** (TI hub fonksiyonu) |
| Generic TAXII (XSOAR/XDR/EDR) | **3.1.10.4** + **3.1.5.1** (EDR'a IoC besleme) |
| Firewall / proxy (ana sayfa) | **3.1.6.4** (Kara Liste Kullanımı), **3.1.6.5** (İzin Verilmeyen Trafik), **3.1.6.20** (URL Filtreleri) |

> Detaylı eşleştirme için: [../bg-rehber-mapping.md](../bg-rehber-mapping.md)

Her doküman aşağıdaki bölümleri içerir:

1. **Hedef** — Entegrasyon sonunda elde edilecek durum
2. **BG Rehberi karşılığı** — Hangi tedbiri karşıladığı
3. **Ön koşullar** — Sürüm, yetki, ağ erişimi
4. **Adım-adım kurulum** — UI talimatları + REST/CLI eşdeğerleri
5. **Doğrulama** — Çalıştığını kanıtlama yolu
6. **Önerilen kurallarla bağlantı** — Hangi UC'leri devreye alınabilir
7. **Troubleshooting** — Sık karşılaşılan sorunlar

## Index

| Hedef sistem | Doküman | Birincil BG madde |
|--------------|---------|-------------------|
| **IBM QRadar** | [qradar.md](qradar.md) | 3.1.8.7 |
| **Splunk Enterprise / ES / Cloud** | [splunk.md](splunk.md) | 3.1.8.7 |
| **MISP** | [misp.md](misp.md) | 3.1.10.4 |
| **OpenCTI** | [opencti.md](opencti.md) | 3.1.10.4 |
| **Microsoft Sentinel** | [sentinel.md](sentinel.md) | 3.1.8.7 + 4.3 (bulut) |
| **Diğer** (XSOAR, Trellix XDR, Falcon, Elastic, Suricata, Wazuh) | [generic-stix.md](generic-stix.md) | 3.1.5.1 + 3.1.10.4 |

## Hangi entegrasyon kim için?

- **Sadece engelleme istiyorum (firewall/proxy)** → ana sayfa düz metin
  feed'leri ([../index.html](../index.html)) —
  BG **3.1.6.4 / 3.1.6.5 / 3.1.6.20** karşılığı.
- **SIEM kuralları + alarm istiyorum** → QRadar / Splunk —
  BG **3.1.8.7 + 3.1.10.4** karşılığı.
- **Threat intel platformu / korelasyon hub'ı** → MISP veya OpenCTI —
  BG **3.1.10.4** karşılığı.
- **Cloud SOC (Azure)** → Sentinel — BG **3.1.8.7 + 4.3 (Bulut Bilişim)**.
- **EDR / XDR / SOAR'a IoC besle** → [generic-stix.md](generic-stix.md)
  (XSOAR, Trellix XDR, Falcon, Defender XDR) — BG **3.1.5.1** karşılığı.

## Veri tazeliği

| Sistem | Yöntem | Cadence |
|--------|--------|---------|
| QRadar TI | Built-in TAXII feed (saatlik polling, `added_after`) | 1 saat |
| Splunk ES TI Manager | Built-in TAXII (saatlik) | 1 saat |
| Splunk Core | `taxii2://` modular input | 1 saat |
| MISP | Native TAXII server pull | 1 saat (scheduled task) |
| OpenCTI | `external-import-taxii` connector | 1 saat (`TAXII2_INTERVAL`) |
| Sentinel | Built-in TAXII data connector | 1 saat (Hourly) |
| XSOAR / XDR / Falcon | Built-in TAXII feed | 1 saat |
| Suricata / Wazuh (text slice) | curl + reload | 1 saat (cron) |

> **Neden 1 saat?** SGB API delta sync cadence'imiz saatliktir; entegrasyon
> bu tempoyu eşlerse tazelik kaybı olmaz. **3.1.5.1**'in "imza/IoC veri
> tabanı güncel olmalı" ifadesinin somut karşılığıdır. Cloudflare edge
> cache TTL 300 sn olduğundan TAXII polling cevabı dakikalar içinde
> tazelenir.

## Self-host (TAXII'ye outbound erişimi olmayan ortamlar için)

Public TAXII endpoint'e ulaşamayan ortamlar (air-gapped, kısıtlı egress)
kendi TAXII servisinizi self-host edebilir; SIEM/TIP iç host'a bağlanır:

- Docker tek konteyner: [../setup-docker.md](../setup-docker.md)
- Kubernetes: [../setup-k8s.md](../setup-k8s.md)
- Self-hosted GitLab (Pages): [../setup-gitlab.md](../setup-gitlab.md)

Her üç yöntemde de aynı statik TAXII ağacı (`docs/taxii/`) nginx ile
servis edilir; SIEM tarafında URL host kısmını kendi adresinizle
değiştirmek yeter.
